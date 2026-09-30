#!/usr/bin/env node
// 대상 파일과 "같은 커밋에서 함께 바뀐 파일"을 git 히스토리에서 세어 낸다.
// 태스크를 시작하기 전에 어디를 같이 봐야 하는지 가늠하는 용도다.
//
//   node cochange.js <파일경로> [파일경로...]
//
// 두 비율을 낸다. 뜻이 다르므로 섞어 읽지 않는다.
//   동반율  = 대상이 바뀐 커밋 중 그 파일도 바뀐 비율. "대상을 고치면 이것도 고치게 되나"
//   역방향  = 그 파일이 바뀐 커밋 중 대상도 바뀐 비율. "이것이 바뀔 때 대상도 바뀌나"
// 사이드이펙트를 가늠할 때 보는 것은 동반율이고, 역방향은 그 관계가 한쪽으로만 쏠렸는지 알려준다.
//
// 의존성을 두지 않는다. node 내장 모듈만 쓴다.

const { execFileSync } = require('child_process');
const path = require('path');

// 한 커밋이 이보다 많은 파일을 건드렸으면 세지 않는다.
// 대규모 리팩터링·포맷 일괄 적용이 섞이면 모든 파일이 서로 동반한 것처럼 보인다.
const MAX_FILES_PER_COMMIT = 40;
const TOP_N = 10;

function git(args, cwd) {
  // git의 stderr는 버린다. 실패는 아래 fail()이 우리 문구로 알리므로,
  // 그대로 두면 분석 로그에 "fatal: ..."이 섞여 두 번 말하는 꼴이 된다.
  return execFileSync('git', args, {
    cwd,
    maxBuffer: 512 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'ignore'],
  }).toString();
}

function fail(msg) {
  console.log(msg);
  process.exit(0); // 분석을 멈추게 하지 않는다. 신호가 없다는 것도 결과다.
}

const inputs = process.argv.slice(2);
if (!inputs.length) fail('사용법: node cochange.js <파일경로> [파일경로...]');

// 저장소는 cwd가 아니라 첫 입력 파일이 있는 자리에서 찾는다.
// 어느 디렉터리에서 실행하든, worktree를 가리켜도 그 worktree의 히스토리를 보게 된다.
const firstAbs = path.resolve(process.cwd(), inputs[0]);
let root;
try {
  root = git(['rev-parse', '--show-toplevel'], path.dirname(firstAbs)).trim();
} catch {
  fail('git 저장소가 아니다 — 동반 파일 분석을 건너뛴다.');
}

let log;
try {
  log = git(['log', '--format=%x00%H', '--name-only', '--no-merges'], root);
} catch {
  fail('커밋 히스토리를 읽지 못했다 — 동반 파일 분석을 건너뛴다.');
}

// 커밋별 파일 목록으로 쪼갠다. %x00(NUL)으로 커밋 경계를 표시했다.
const commits = [];
for (const chunk of log.split('\0')) {
  const lines = chunk.split('\n').map(l => l.trim()).filter(Boolean);
  if (lines.length < 2) continue;
  lines.shift(); // SHA
  if (lines.length <= MAX_FILES_PER_COMMIT) commits.push(lines);
}
if (!commits.length) fail('셀 수 있는 커밋이 없다 — 동반 파일 분석을 건너뛴다.');

// 파일별 등장 커밋 수와, 파일 쌍의 동시 등장 수
const seen = new Map();
const pairs = new Map();
for (const files of commits) {
  for (const f of files) seen.set(f, (seen.get(f) || 0) + 1);
  for (let i = 0; i < files.length; i++) {
    for (let j = i + 1; j < files.length; j++) {
      const key = files[i] < files[j] ? files[i] + '\0' + files[j] : files[j] + '\0' + files[i];
      pairs.set(key, (pairs.get(key) || 0) + 1);
    }
  }
}

// 입력 경로를 저장소 상대 경로로 맞춘다. 절대경로와 상대경로를 모두 받는다.
function toRepoPath(input) {
  const abs = path.resolve(process.cwd(), input);
  if (!abs.startsWith(root + path.sep)) return null;
  return abs.slice(root.length + 1);
}

console.log(`저장소 ${path.basename(root)} · 커밋 ${commits.length}개 · 추적 파일 ${seen.size}개`);

for (const input of inputs) {
  const target = toRepoPath(input);
  console.log('');
  if (target === null) {
    console.log(`[${input}] 이 저장소 밖의 경로다 — 건너뛴다.`);
    continue;
  }
  const own = seen.get(target) || 0;
  if (!own) {
    console.log(`[${target}] 히스토리에 없다. 새 파일이거나 경로가 바뀐 것이다 — 동반 파일을 셀 수 없다.`);
    continue;
  }

  const together = [];
  for (const [key, n] of pairs) {
    const i = key.indexOf('\0');
    const a = key.slice(0, i);
    const b = key.slice(i + 1);
    if (a === target) together.push([b, n]);
    else if (b === target) together.push([a, n]);
  }
  together.sort((x, y) => y[1] - x[1]);

  console.log(`[${target}] 이 파일이 바뀐 커밋 ${own}개`);
  if (!together.length) {
    console.log('  함께 바뀐 파일이 없다 — 늘 혼자 바뀌었다.');
    continue;
  }
  console.log('  동반율  역방향  횟수  파일');
  for (const [f, n] of together.slice(0, TOP_N)) {
    const fwd = Math.round((n / own) * 100);
    const rev = Math.round((n / (seen.get(f) || n)) * 100);
    console.log(
      `  ${String(fwd).padStart(4)}%  ${String(rev).padStart(5)}%  ${String(n).padStart(4)}  ${f}`
    );
  }
  if (together.length > TOP_N) console.log(`  … 그 밖에 ${together.length - TOP_N}개`);
}
