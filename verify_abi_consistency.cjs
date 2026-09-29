// Cross-checks the ABIs compiled from the .sol interfaces against the published
// JSON ABIs. This is the regression guard for the tuple-drift class of defect:
// a struct field that is missing or reordered in the .sol file compiles cleanly
// but produces calldata that decodes to the wrong values, so the only reliable
// check is a structural diff of the two artifacts.
//
// Usage: node verify_abi_consistency.cjs
const fs = require('node:fs')
const path = require('node:path')
const { execFileSync } = require('node:child_process')

const SOLC = process.env.SOLC_PATH
if (!SOLC) {
  console.error('SOLC_PATH env var must point at a solc >=0.8.28 binary')
  process.exit(2)
}

const ROOT = __dirname

// [ .sol file, published ABI file ]
const PAIRS = [
  ['interfaces/IPeripheral.sol', 'abis/AmmalgamPeripheral.json'],
  ['interfaces/factories/IAmmalgamFactory.sol', 'abis/AmmalgamFactory.json'],
]

/**
 * Normalizes an ABI entry to a comparable shape, expanding tuples.
 *
 * Only the *types* are compared strictly. Parameter and component names are
 * cosmetic: they do not enter the function selector and do not change the
 * calldata layout, so a naming difference between the .sol file and the
 * published ABI is reported but is not a failure. The tuple field *order* and
 * field *types* are what matter, and those are captured by the expanded type
 * string.
 */
function typeSignature(entry) {
  const renderType = (i) => {
    if (i.type === 'tuple' || i.type === 'tuple[]') {
      const inner = '(' + (i.components || []).map(renderType).join(',') + ')'
      return i.type === 'tuple[]' ? inner + '[]' : inner
    }
    return i.type
  }
  return {
    name: entry.name,
    type: entry.type,
    inputs: (entry.inputs || []).map(renderType),
    outputs: (entry.outputs || []).map(renderType),
  }
}

function nameSignature(entry) {
  const names = (list) => (list || []).map((i) => i.name)
  return {
    name: entry.name,
    inputs: names(entry.inputs),
    outputs: names(entry.outputs),
  }
}

// solc --abi can emit several interfaces from one source file, and two of them
// may legitimately declare the same function name (IAmmalgamFactory and
// IPairFactory both declare `createPair`). Group by contract name so entries do
// not collapse into one another.
function compileSolidity(relSol) {
  const out = execFileSync(
    SOLC,
    ['--base-path', ROOT, '--include-path', path.join(ROOT, 'node_modules'),
     '--allow-paths', ROOT, '--abi', relSol],
    { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
  )
  // solc --abi output is:
  //   ======= path:Name =======
  //   Contract JSON ABI
  //   [ ...json... ]
  // so the JSON is the first line after the banner that starts with '['.
  const lines = out.split('\n')
  const byContract = new Map()
  for (let i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('=======')) continue
    const contractName = lines[i].split(':').pop().replace(/=+\s*$/, '').trim()
    for (let j = i + 1; j < lines.length && !lines[j].startsWith('======='); j++) {
      const t = lines[j].trim()
      if (t.startsWith('[')) {
        if (!byContract.has(contractName)) byContract.set(contractName, [])
        byContract.get(contractName).push(...JSON.parse(t))
        break
      }
    }
  }
  return byContract
}

let failures = 0

for (const [solRel, jsonRel] of PAIRS) {
  console.log(`\n=== ${solRel}  <->  ${jsonRel} ===`)
  let byContract
  try {
    byContract = compileSolidity(solRel)
  } catch (e) {
    console.log(`  COMPILE FAILED: ${String(e.stderr || e.message).split('\n').slice(0, 8).join('\n')}`)
    failures++
    continue
  }
  const published = JSON.parse(fs.readFileSync(path.join(ROOT, jsonRel), 'utf8'))

  const key = (e) => `${e.type}:${e.name}`

  // Collect every compiled entry under its key. A key may have more than one
  // candidate (two interfaces declaring the same name); a key is satisfied if
  // ANY candidate's types match the published ABI.
  const candidatesByKey = new Map()
  for (const entries of byContract.values()) {
    for (const e of entries) {
      const k = key(e)
      if (!candidatesByKey.has(k)) candidatesByKey.set(k, [])
      candidatesByKey.get(k).push(e)
    }
  }

  for (const pub of published) {
    const k = key(pub)
    const candidates = candidatesByKey.get(k)
    if (!candidates) {
      // The published ABI is a superset (it also carries events, custom errors
      // and admin-only functions), which is expected and allowed.
      console.log(`  info   only in published ABI: ${k}`)
      continue
    }
    const pubTypes = JSON.stringify(typeSignature(pub))
    const agree = candidates.find((c) => JSON.stringify(typeSignature(c)) === pubTypes)
    if (!agree) {
      console.log(`  MISMATCH ${k}`)
      for (const c of candidates) console.log(`    .sol  : ${JSON.stringify(typeSignature(c))}`)
      console.log(`    abi   : ${pubTypes}`)
      failures++
      continue
    }
    const nameDiff = JSON.stringify(nameSignature(agree)) !== JSON.stringify(nameSignature(pub))
    console.log(`  match   ${k}${nameDiff ? '  (param names differ - cosmetic)' : ''}`)
  }
}

console.log('\n-----')
if (failures === 0) {
  console.log('ABI_CONSISTENCY: PASS')
} else {
  console.log(`ABI_CONSISTENCY: FAIL (${failures} mismatch(es))`)
}
process.exit(failures === 0 ? 0 : 1)
