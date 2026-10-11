# domain-skill-architect 硬校验器（CI）V8.5：21 门，门不过即非零退出，证据自动抽取，构建者无法伪造
# 用法: verify-gates.ps1 -SkillDir <skill目录> [-ReportPath <文件>]
param(
  [Parameter(Mandatory=$true)][string]$SkillDir,
  [string]$ReportPath
)
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$ErrorActionPreference='Stop'

$PREFIX='SRC','CLM','EVI','QST','ENT','TASK','DEC','ROLE','RSK','TRM','MET','TOL','GAP'
$EV    = 0..6 | ForEach-Object { "E$_" }
$CUR   = '现行','已修订','已废止','待核'
$FRESH = 'STABLE','MODERATE','VOLATILE','REAL_TIME'
$TRUTH = 'VERIFIED','CORROBORATED','CONDITIONALLY_VERIFIED','PRACTICE','INFERENCE','HEURISTIC','UNKNOWN','CONFLICTED','STALE','REJECTED'
$ABBREV_OK = @('AI','APP','URL','API','ID','SSOT','FSM','CAUSES','HTTP','HTTPS') + $PREFIX + @('DOMAIN','ORG','EXECUTION','REVIEW','VETO','ESCALATION') + $FRESH + $TRUTH
$MIXED_OK  = 'http','https','skill','name','description','type','md','Registry'

$results=@()
function Add-Result($gate,$name,$pass,$evidence){
  $script:results += [pscustomobject]@{Gate=$gate;Name=$name;Result=$(if($pass){'PASS'}else{'FAIL'});Evidence=($evidence -join ' | ')}
}
function Split-Cells($line){
  $c=$line -split '\|'
  if($c.Count -lt 3){ return @() }
  @($c[1..($c.Count-2)] | ForEach-Object { $_.Trim() })
}
function Parse-Table($block){
  $ln=@($block -split "`n" | Where-Object { $_ -match '^\s*\|.*\|\s*$' })
  if($ln.Count -lt 2){ return $null }
  $header=Split-Cells $ln[0]
  $rows=@()
  for($i=2;$i -lt $ln.Count;$i++){ $rows += ,(Split-Cells $ln[$i]) }
  [pscustomobject]@{Header=$header;Rows=$rows}
}
function Col-Index($tbl,$regex){
  if($null -eq $tbl){ return -1 }
  for($i=0;$i -lt $tbl.Header.Count;$i++){ if($tbl.Header[$i] -match $regex){ return $i } }
  return -1
}

# ---------- 定位 / 分类文件 ----------
if(-not (Test-Path $SkillDir)){ Write-Error "SkillDir 不存在: $SkillDir" }
$pSkill   = Join-Path $SkillDir 'SKILL.md'
$refDir   = Join-Path $SkillDir 'references'
$pReg     = Join-Path $refDir 'canonical-registry.md'
$pExpert  = Join-Path $refDir 'expert-team.md'
$pPlay    = Join-Path $refDir 'playbooks.md'
$pAuth    = Join-Path $refDir 'authority-register.md'
$pPlan    = Join-Path $refDir 'research-plan.md'
$pClar    = Join-Path $refDir 'clarification-log.md'
$pFresh   = Join-Path $refDir 'freshness-ledger.md'
$pValid   = Join-Path $refDir 'domain-validation.md'

$domainMd=@()
if(Test-Path $pSkill){ $domainMd += Get-Item $pSkill }
if(Test-Path $refDir){ $domainMd += @(Get-ChildItem $refDir -Filter *.md) }
$corpus = ($domainMd | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
$bases=@()
if(Test-Path $refDir){ $bases=@(Get-ChildItem $refDir -Filter *.md | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) }) }
function Read-If($p){ if(Test-Path $p){ [IO.File]::ReadAllText($p) } else { '' } }

# ---------- G-0 完整性（R3 完整文件集）----------
$g0=@()
foreach($p in $pSkill,$pReg,$pExpert,$pPlay,$pAuth,$pPlan,$pClar,$pFresh,$pValid){
  if(-not (Test-Path $p)){ $g0 += "缺 " + $p.Replace($SkillDir,'.') }
}
$skillText=Read-If $pSkill
$fm=[regex]::Match($skillText,'(?s)\A---(.*?)---')
if(-not $fm.Success){ $g0 += 'SKILL frontmatter 缺失/围栏损坏' }
else{
  $fmbody=$fm.Groups[1].Value
  if(([regex]::Matches($fmbody,'(?m)^\s*name:')).Count -ne 1){ $g0 += 'frontmatter name 缺失/重复' }
  if($fmbody -notmatch '(?m)^\s*description:'){ $g0 += 'frontmatter description 缺失' }
}
# G-0 的最终判定在 registry 节序解析后合并（含节-表身份校验）

# ---------- 解析 registry（V8.4 节序 §A-§O）----------
$reg=Read-If $pReg
$sec=@{}
$heads=[regex]::Matches($reg,'(?m)^##\s+(§[A-O])\b')
for($i=0;$i -lt $heads.Count;$i++){
  $start=$heads[$i].Index
  $end= if($i+1 -lt $heads.Count){ $heads[$i+1].Index } else { $reg.Length }
  $sec[$heads[$i].Groups[1].Value]=$reg.Substring($start,$end-$start)
}
$tSrc  =if($sec.ContainsKey('§B')){Parse-Table $sec['§B']}
$tClm  =if($sec.ContainsKey('§C')){Parse-Table $sec['§C']}
$tEvi  =if($sec.ContainsKey('§D')){Parse-Table $sec['§D']}
$tQst  =if($sec.ContainsKey('§E')){Parse-Table $sec['§E']}
$tEnt  =if($sec.ContainsKey('§F')){Parse-Table $sec['§F']}
$tTask =if($sec.ContainsKey('§G')){Parse-Table $sec['§G']}
$tDec  =if($sec.ContainsKey('§H')){Parse-Table $sec['§H']}
$tRole =if($sec.ContainsKey('§I')){Parse-Table $sec['§I']}
$tRsk  =if($sec.ContainsKey('§J')){Parse-Table $sec['§J']}
$tMet  =if($sec.ContainsKey('§L')){Parse-Table $sec['§L']}
$tTol  =if($sec.ContainsKey('§M')){Parse-Table $sec['§M']}

$defined=New-Object System.Collections.Generic.HashSet[string]
foreach($m in [regex]::Matches($reg,('\b('+($PREFIX -join '|')+')-\d{3}'))){ [void]$defined.Add($m.Value) }

# G-0 追加：节-表身份一致性（节序错位给准确诊断，而非下游逐行误判）
$secExpect=[ordered]@{ '§B'='SRC';'§C'='CLM';'§D'='EVI';'§E'='QST';'§F'='ENT';'§G'='TASK';'§H'='DEC';'§I'='ROLE';'§J'='RSK';'§K'='TRM';'§L'='MET';'§M'='TOL';'§N'='GAP' }
foreach($sk in $secExpect.Keys){
  if($sec.ContainsKey($sk)){
    $tt=Parse-Table $sec[$sk]
    if($tt -and $tt.Rows.Count -gt 0){
      $pm2=[regex]::Match($tt.Rows[0][0],'^([A-Z]{2,6})-\d{3}')
      $actual=if($pm2.Success){$pm2.Groups[1].Value}else{'无法识别'}
      if($actual -ne $secExpect[$sk]){ $g0 += "$sk 表身份错位：应为$($secExpect[$sk])，实际为$actual" }
    }
  }
}
Add-Result 'G-0' '完整性' ($g0.Count -eq 0) $(if($g0){$g0}else{'R3 文件/frontmatter/节序 齐全'})

# ---------- G-INTENT 意图契约 ----------
$gi1=@()
$plan=Read-If $pPlan
if($plan -notmatch '目标契约'){ $gi1 += 'research-plan 缺目标契约' }
foreach($k in '目标','场景','风险','成功条件'){ if($plan -notmatch $k){ $gi1 += "目标契约缺要素: $k" } }
Add-Result 'G-INTENT' '意图契约' ($gi1.Count -eq 0) $(if($gi1){$gi1}else{'目标契约四要素齐'})

# ---------- G-QUESTION 提问路由 ----------
$gi2=@()
$clar=Read-If $pClar
if($null -eq $tQst){ $gi2 += 'registry 缺 QST 表' }
if($clar -notmatch '必要性'){ $gi2 += 'clarification-log 缺必要性判断' }
if($tQst){
  $ciAns=Col-Index $tQst '回答|answer'; $ciFb=Col-Index $tQst '假设回退|fallback'; $ciBlk=Col-Index $tQst '阻断|blocking'
  for($i=0;$i -lt $tQst.Rows.Count;$i++){
    $hasRoute=$false
    foreach($ci in $ciAns,$ciFb,$ciBlk){ if($ci -ge 0 -and $tQst.Rows[$i][$ci]){ $hasRoute=$true } }
    if(-not $hasRoute){ $gi2 += "$($tQst.Rows[$i][0]) 无回答/假设/阻断路由" }
  }
}
Add-Result 'G-QUESTION' '提问路由' ($gi2.Count -eq 0) $(if($gi2){$gi2|Select-Object -First 8}else{'关键未知均有路由，必要性已判'})

# ---------- G-DECOMP 递归分解 ----------
$gi3=@()
if($plan -notmatch '分解树|分解结构'){ $gi3 += 'research-plan 缺分解树' }
$pseudo='研究一下|分析一下|验证一下|根据情况处理|酌情处理'
$pm=[regex]::Matches($corpus,$pseudo)
if($pm.Count -gt 0){ $gi3 += '存在伪原子动作 x'+$pm.Count }
Add-Result 'G-DECOMP' '递归分解' ($gi3.Count -eq 0) $(if($gi3){$gi3}else{'分解到原子单元，无伪动作'})

# ---------- G-AUTHORITY 最高适用权威 ----------
$gi4=@()
$auth=Read-If $pAuth
if($auth -notmatch '最高适用权威'){ $gi4 += 'authority-register 缺最高适用权威解析' }
if($auth -notmatch '约束力|绑定力'){ $gi4 += '缺约束力/适用范围记录' }
if($tClm){
  $ciPS=Col-Index $tClm '主要来源|primary'
  if($ciPS -ge 0){ for($i=0;$i -lt $tClm.Rows.Count;$i++){
    if($tClm.Rows[$i][$ciPS] -notmatch '(SRC|CLM)-\d' -and $tClm.Rows[$i][$ciPS] -notmatch '待核'){ $gi4 += "$($tClm.Rows[$i][0]) 缺主要权威来源" }
  } }
}
Add-Result 'G-AUTHORITY' '最高适用权威' ($gi4.Count -eq 0) $(if($gi4){$gi4|Select-Object -First 8}else{'主张均解析最高权威与约束力'})

# ---------- G-TRUTH 主张-证据-来源 ----------
$gi5=@()
if($null -eq $tClm){ $gi5 += '缺 CLM 表' }
if($null -eq $tEvi){ $gi5 += '缺 EVI 表' }
$valid=Read-If $pValid
if($valid -notmatch '独立重建'){ $gi5 += 'domain-validation 缺独立重建对拍' }
if($tClm){
  $ciTS=Col-Index $tClm '真值|truth'; $ciEV=Col-Index $tClm '证据|EVI'; $ciPS=Col-Index $tClm '主要来源'
  for($i=0;$i -lt $tClm.Rows.Count;$i++){
    if($ciTS -ge 0 -and -not $tClm.Rows[$i][$ciTS]){ $gi5 += "$($tClm.Rows[$i][0]) 缺真值状态" }
    $hassrc=$false
    foreach($ci in $ciEV,$ciPS){ if($ci -ge 0 -and $tClm.Rows[$i][$ci] -match '(EVI|SRC)-\d'){ $hassrc=$true } }
    if(-not $hassrc){ $gi5 += "$($tClm.Rows[$i][0]) 未挂证据/来源" }
  }
}
if($tEvi){ $ciS=Col-Index $tEvi '来源|src'
  if($ciS -ge 0){ foreach($r in $tEvi.Rows){ if($r[$ciS] -notmatch 'SRC-\d'){ $gi5 += "$($r[0]) 证据未挂 SRC" } } }
}
Add-Result 'G-TRUTH' '主张真相' ($gi5.Count -eq 0) $(if($gi5){$gi5|Select-Object -First 8}else{'CLM↔EVI↔SRC 闭合，独立重建在'})

# ---------- G-FRESH 时效核验 ----------
$gi6=@()
$freshLedger=Read-If $pFresh
foreach($k in '当前','生效','替代'){ if($freshLedger -notmatch $k){ $gi6 += "freshness-ledger 缺$k 核验" } }
if($tClm){
  $ciFC=Col-Index $tClm '时效|fresh'; $ciLV=Col-Index $tClm '最近核验|verified'
  for($i=0;$i -lt $tClm.Rows.Count;$i++){
    $fc=if($ciFC -ge 0){$tClm.Rows[$i][$ciFC]}else{''}
    if(-not $fc){ $gi6 += "$($tClm.Rows[$i][0]) 缺时效类" }
    elseif($fc -notin $FRESH){ $gi6 += "$($tClm.Rows[$i][0]) 时效类非法: $fc" }
    if($fc -in 'VOLATILE','REAL_TIME'){ if($ciLV -ge 0 -and $tClm.Rows[$i][$ciLV] -notmatch '\d{4}'){ $gi6 += "$($tClm.Rows[$i][0]) 高时效缺现场核验日期" } }
  }
}
Add-Result 'G-FRESH' '时效核验' ($gi6.Count -eq 0) $(if($gi6){$gi6|Select-Object -First 8}else{'时效类合法，替代链与现场核验齐'})

# ---------- G-DOMAIN 领域闭合与冻结 ----------
$gi7=@()
if($valid -notmatch '闭合|Closure'){ $gi7 += 'domain-validation 缺模型闭合记录' }
$fp=[regex]::Match($valid,'DOMAIN_IR_FINGERPRINT[：: ]*([A-Za-z0-9_\-]{6,})')
if(-not $fp.Success){ $gi7 += '缺有效 DOMAIN_IR_FINGERPRINT' }
if(-not $sec.ContainsKey('§N')){ $gi7 += '缺 GAP 表（未知未对拍）' }
Add-Result 'G-DOMAIN' '领域闭合/冻结' ($gi7.Count -eq 0) $(if($gi7){$gi7}else{'模型闭合，冻结指纹有效，GAP对拍'})

# ---------- G-ENUM 封闭枚举 + ROLE 前缀 ----------
$ge=@()
foreach($m in [regex]::Matches($corpus,'\bE\d')){ if($m.Value -notin $EV){ $ge += "证据标签越界 $($m.Value)" } }
foreach($m in [regex]::Matches($corpus,'极高|极低')){ $ge += '风险等级越词' }
if($tRole){ for($i=0;$i -lt $tRole.Rows.Count;$i++){
  if($tRole.Rows[$i][0] -notmatch 'ROLE-\d{3}'){ $ge += "角色ID非ROLE: $($tRole.Rows[$i][0])" }
} }
foreach($m in [regex]::Matches($corpus,'\b([A-Z]{2,6})-\d{3}')){ if($m.Groups[1].Value -notin $PREFIX){ $ge += "ID前缀越界: $($m.Groups[1].Value)" } }
if($tClm){
  $ciTS=Col-Index $tClm '真值|truth'; $ciFC=Col-Index $tClm '时效|fresh'
  for($i=0;$i -lt $tClm.Rows.Count;$i++){
    if($ciTS -ge 0){ $v=$tClm.Rows[$i][$ciTS]; if($v -and $v -notin $TRUTH){ $ge += "真值状态越界: $v" } }
    if($ciFC -ge 0){ $v=$tClm.Rows[$i][$ciFC]; if($v -and $v -notin $FRESH){ $ge += "时效类越界: $v" } }
  }
}
Add-Result 'G-ENUM' '封闭枚举/ROLE' ($ge.Count -eq 0) $(if($ge){$ge|Select-Object -First 8}else{'受控值在枚举内，角色=ROLE-NNN'})

# ---------- G-SEQ 序号连续 ----------
$gs=@()
foreach($pref in $PREFIX){
  $nums=[regex]::Matches($reg,("\b"+$pref+'-(\d{3})'))|ForEach-Object{[int]$_.Groups[1].Value}|Sort-Object -Unique
  if($nums.Count -gt 0){ if(Compare-Object (1..$nums[-1]) $nums){ $gs += "$pref 序号不连续" } }
}
Add-Result 'G-SEQ' '序号连续' ($gs.Count -eq 0) $(if($gs){$gs}else{'各类ID 001..N 连续'})

# ---------- G-LANG 语言纯度 ----------
function Clean-ForLang($s,$isEntry,$bases){
  if($isEntry){ $s=[regex]::Replace($s,'(?s)\A---.*?---',' ') }
  $s=[regex]::Replace($s,'(?s)```.*?```',' ')
  $s=[regex]::Replace($s,('\b('+($PREFIX -join '|')+')-\d{3}'),' ')
  foreach($e in ($TRUTH+$FRESH)){ $s=[regex]::Replace($s,('\b'+[regex]::Escape($e)+'\b'),' ') }
  $s=[regex]::Replace($s,'DOMAIN_IR_FINGERPRINT[：:\s]*[A-Za-z0-9_\-]+',' ')
  $s=[regex]::Replace($s,'https?://[^\s|)]+',' ')
  $s=[regex]::Replace($s,'[\w.\\/-]+\.md',' ')
  $s=[regex]::Replace($s,'[a-z0-9\-]+(\.[a-z0-9\-]+)+',' ')
  foreach($b in $bases){ $s=[regex]::Replace($s,('\b'+[regex]::Escape($b)+'\b'),' ') }
  return $s
}
$langText=(($domainMd|ForEach-Object{ Clean-ForLang ([IO.File]::ReadAllText($_.FullName)) ($_.Name -eq 'SKILL.md') $bases }) -join ' ')
$trmAbbr=New-Object System.Collections.Generic.HashSet[string]
if($sec.ContainsKey('§K')){ foreach($m in [regex]::Matches($sec['§K'],'[A-Z]{2,}')){ [void]$trmAbbr.Add($m.Value) } }
$gl=@()
foreach($m in [regex]::Matches($langText,'[A-Za-z]{2,}')){
  $w=$m.Value
  if($w -cmatch '^[A-Z]+$'){ if($w -notin $ABBREV_OK -and -not $trmAbbr.Contains($w)){ $gl += "缩写未对照: $w" } }
  else { if($w -notin $MIXED_OK){ $gl += "非白名单外文: $w" } }
}
Add-Result 'G-LANG' '语言纯度' ($gl.Count -eq 0) $(if($gl){$gl|Select-Object -First 12}else{'外文均中文化/已对照'})

# ---------- G-XREF 交叉引用 + 决策权对拍 ----------
$gx=@()
$referenced=New-Object System.Collections.Generic.HashSet[string]
foreach($m in [regex]::Matches($corpus,('\b('+($PREFIX -join '|')+')-\d{3}'))){ [void]$referenced.Add($m.Value) }
foreach($r in $referenced){ if(-not $defined.Contains($r)){ $gx += "引用未定义ID: $r" } }
if($tDec){
  $ciP=Col-Index $tDec '提案'; $ciD=Col-Index $tDec '决定'; $ciV=Col-Index $tDec '否决'
  for($i=0;$i -lt $tDec.Rows.Count;$i++){ foreach($ci in $ciP,$ciD,$ciV){ if($ci -lt 0){continue}
    foreach($tok in [regex]::Matches($tDec.Rows[$i][$ci],'M\d{1,2}|ROLE-\d{3}')){ $tv=$tok.Value
      if($tv -match '^M\d'){ $gx += "DEC $($tDec.Rows[$i][0]) 角色非ROLE: $tv" }
      elseif(-not $defined.Contains($tv)){ $gx += "DEC 角色未定义: $tv" }
    }
  } }
}
if($tRole){
  $ciT=Col-Index $tRole '来源任务|source_task'; $ciC=Col-Index $tRole '来源决策|source_dec'
  for($i=0;$i -lt $tRole.Rows.Count;$i++){ foreach($ci in $ciT,$ciC){ if($ci -lt 0){continue}
    $stripped=[regex]::Replace($tRole.Rows[$i][$ci],'(TASK|DEC)-\d{3}','')
    if($stripped -match '\d{2,3}'){ $gx += "ROLE 引用非完整ID: $($tRole.Rows[$i][0])" }
  } }
}
Add-Result 'G-XREF' '交叉引用/决策权' ($gx.Count -eq 0) $(if($gx){$gx|Select-Object -First 10}else{'引用闭合，决策权角色均ROLE'})

# ---------- G-EVIDENCE 证据字段 + URL ----------
$gev=@()
if($tSrc){
  $ciU=Col-Index $tSrc 'URL'; $ciS=Col-Index $tSrc '状态'; $ciEff=Col-Index $tSrc '施行'
  for($i=0;$i -lt $tSrc.Rows.Count;$i++){ $id=$tSrc.Rows[$i][0]
    $url=if($ciU -ge 0){$tSrc.Rows[$i][$ciU]}else{''}
    if($url -notmatch '待核'){ $link=[regex]::Match($url,'https?://[^\s|)]+')
      if($link.Success){ try{ $u=[Uri]$link.Value
        if($u.AbsolutePath -in '/','' -or $url -match '检索|搜索|为准'){ $gev += "$id URL 根/检索入口" }
      }catch{ $gev += "$id URL 非法" } } else { $gev += "$id URL 缺失" }
    } else { $gev += "$id URL 待核（须补）" }
    if($ciS -ge 0){ $st=$tSrc.Rows[$i][$ciS]; if($st -and $st -notin $CUR){ $gev += "$id 状态非法: $st" } }
    if($ciEff -ge 0){ $ef=$tSrc.Rows[$i][$ciEff]; if($ef -and $ef -notmatch '\d{4}' -and $ef -notmatch '待核'){ $gev += "$id 施行日期缺失: $ef" } }
  }
}
Add-Result 'G-EVIDENCE' '证据字段/URL' ($gev.Count -eq 0) $(if($gev){$gev|Select-Object -First 10}else{'字段齐，URL均深路径'})

# ---------- G-ATOMIC 原子一来源 ----------
$gat=@()
if($tSrc){ $ciO=Col-Index $tSrc '条款|义务'
  if($ciO -ge 0){ foreach($r in $tSrc.Rows){ if($r[$ciO] -match 'SRC-\d{3}'){ $gat += "$($r[0]) 义务列引用其他来源" } } }
}
Add-Result 'G-ATOMIC' '原子一来源' ($gat.Count -eq 0) $(if($gat){$gat}else{'原子事实单一主来源'})

# ---------- G-QUANT 定量口径 ----------
$quantRe='(\d+(?:\.\d+)?)\s*(年|万元|元|%|％|个月|天|日)'
$authNums=New-Object System.Collections.Generic.HashSet[string]
if($tSrc){ $ciO=Col-Index $tSrc '条款|义务'
  if($ciO -ge 0){ foreach($r in $tSrc.Rows){ foreach($m in [regex]::Matches($r[$ciO],$quantRe)){ [void]$authNums.Add($m.Groups[1].Value+$m.Groups[2].Value) } } }
}
$gq=@()
foreach($f in $domainMd){ foreach($line in ([IO.File]::ReadAllText($f.FullName) -split "`n")){
  if($line -match '近\s*\d+\s*个月' -and $line -match '新规|扫描'){ continue }
  foreach($m in [regex]::Matches($line,$quantRe)){ $v=$m.Groups[1].Value+$m.Groups[2].Value
    if(-not $authNums.Contains($v) -and $line -notmatch 'SRC-\d' -and $line -notmatch '待填|待核'){ $gq += "数字无出处: $v" }
  }
} }
Add-Result 'G-QUANT' '定量口径' ($gq.Count -eq 0) $(if($gq){$gq|Select-Object -First 8}else{'定量均带口径与出处'})

# ---------- G-CURRENCY 现行/穷尽 ----------
$gc=@()
$curText=$reg+$auth
if($curText -notmatch '目录枚举'){ $gc += '缺目录枚举记录' }
if($curText -notmatch '穷尽性自检|穷尽性陈述'){ $gc += '缺穷尽性自检' }
if($curText -notmatch '反向覆盖'){ $gc += '缺反向覆盖核对' }
if($tSrc){ $ciS=Col-Index $tSrc '状态'; if($ciS -ge 0){ foreach($r in $tSrc.Rows){ if($r[$ciS] -match '已废止'){ $gc += '出现已废止条文' } } } }
Add-Result 'G-CURRENCY' '现行/穷尽' ($gc.Count -eq 0) $(if($gc){$gc}else{'三证据齐，状态现行'})

# ---------- G-TRACE 双向追溯 ----------
$gtr=@()
if($tRsk){ $ciSrc=Col-Index $tRsk '来源'
  if($ciSrc -ge 0){ for($i=0;$i -lt $tRsk.Rows.Count;$i++){
    if($tRsk.Rows[$i][$ciSrc] -notmatch 'SRC-\d{3}'){ $gtr += "$($tRsk.Rows[$i][0]) 来源无SRC: $($tRsk.Rows[$i][$ciSrc])" }
  } }
}
if(-not $sec.ContainsKey('§O')){ $gtr += '缺 §O 追溯矩阵' }
Add-Result 'G-TRACE' '双向追溯' ($gtr.Count -eq 0) $(if($gtr){$gtr}else{'RSK均挂SRC，追溯矩阵在'})

# ---------- G-KPI 反虚假指标（V8.5：必须含真实业务指标）----------
$gk=@()
$bizRe='转化率|ROI|停留时长|完播率|复购率|客单价|播放量|阅读量|涨粉|互动率|GMV|成交|营收|点击率|曝光|粉丝数|关注数|投产比|获客'
$hasBiz=$false
if($tMet){
  $ciM=Col-Index $tMet '口径|单位'; $ciW=Col-Index $tMet '时间窗'; $ciF=Col-Index $tMet '来源'
  foreach($r in $tMet.Rows){
    if($ciM -ge 0 -and -not $r[$ciM]){ $gk += "$($r[0]) 缺口径" }
    if($ciW -ge 0 -and -not $r[$ciW]){ $gk += "$($r[0]) 缺时间窗" }
    if($ciF -ge 0 -and -not $r[$ciF]){ $gk += "$($r[0]) 缺来源" }
    if(($r -join ' ') -match $bizRe){ $hasBiz=$true }
  }
  if(-not $hasBiz){ $gk += 'MET 全篇只有合规/质检类指标，缺真实业务指标（V8.5 协议）' }
}
Add-Result 'G-KPI' '反虚假指标' ($gk.Count -eq 0) $(if($gk){$gk}else{'指标有口径/窗/来源且含真实业务指标'})

# ---------- G-CONTAM 模板污染（SSOT 驱动）----------
$foreign='OBD|DTC|故障码|变速箱|发动机|处方|医嘱|病历|诉状|输液|焊接|焊缝|PLC'
$ownTerms=''
if($sec.ContainsKey('§F')){ $ownTerms += $sec['§F'] }
if($sec.ContainsKey('§K')){ $ownTerms += $sec['§K'] }
$fc=@()
foreach($m in [regex]::Matches($corpus,$foreign)){ if($ownTerms -notmatch [regex]::Escape($m.Value)){ $fc += "外来模板词未登记: $($m.Value)" } }
Add-Result 'G-CONTAM' '模板污染' ($fc.Count -eq 0) $(if($fc){$fc|Select-Object -First 8}else{'无未登记外来结构'})

# ---------- G-DEPTH 领域深度 ----------
$nEnt=if($tEnt){$tEnt.Rows.Count}else{0}
$nTol=if($tTol){$tTol.Rows.Count}else{0}
$nTask=if($tTask){$tTask.Rows.Count}else{0}
$depthText=$corpus
if($tSrc){ $ciName=Col-Index $tSrc '全称'
  if($ciName -ge 0){ foreach($r in $tSrc.Rows){ if($r[$ciName]){ $depthText=$depthText.Replace($r[$ciName],' ') } } }
}
$vague=[regex]::Matches($depthText,'赋能|协同|抓手|生态|闭环').Count
$depthScore=$nEnt+$nTol+$nTask
Add-Result 'G-DEPTH' '领域深度' ($depthScore -ge 15 -and $vague -le 3) "特有物=$depthScore(ENT$nEnt/TOL$nTol/TASK$nTask) 泛化词=$vague"

# ---------- G-DUTY 职责分离 ----------
$gd2=@()
$hasVeto=$false
if($tRole){ $ciA=Col-Index $tRole '权威'
  if($ciA -ge 0){ foreach($r in $tRole.Rows){ if($r[$ciA] -match 'VETO|REVIEW'){ $hasVeto=$true } } }
}
if(-not $hasVeto){ $gd2 += '缺独立审核/否决角色' }
if($reg -notmatch '否决权只能由|不得因.*解除|不得被.*解除'){ $gd2 += '缺否决权解除路径约束' }
Add-Result 'G-DUTY' '职责分离' ($gd2.Count -eq 0) $(if($gd2){$gd2}else{'分权矩阵在，否决独立'})

# ---------- 输出 ----------
$order='G-INTENT','G-QUESTION','G-DECOMP','G-AUTHORITY','G-TRUTH','G-FRESH','G-DOMAIN','G-0','G-ENUM','G-SEQ','G-LANG','G-XREF','G-EVIDENCE','G-ATOMIC','G-QUANT','G-CURRENCY','G-TRACE','G-KPI','G-CONTAM','G-DEPTH','G-DUTY'
foreach($g in $order){ $r=$results|Where-Object{$_.Gate -eq $g}
  '{0,-11} {1,-14} {2}   {3}' -f $r.Gate,$r.Name,$r.Result,$r.Evidence }
'---'
$nf=@($results|Where-Object{$_.Result -eq 'FAIL'}).Count
"FAIL count = $nf / $($results.Count)"

$stamp=Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$report=@("# 硬校验报告（CI 自动生成 V8.5）","- SkillDir: $SkillDir","- 时间: $stamp","","| 门 | 名称 | 结果 | 证据 |","|---|---|---|---|")
foreach($g in $order){ $r=$results|Where-Object{$_.Gate -eq $g}; $report += "| $($r.Gate) | $($r.Name) | $($r.Result) | $($r.Evidence) |" }
$report += ""; $report += $(if($nf -eq 0){ "结论: DOMAIN_SKILL_GATES_PASS" } else { "结论: 阻断（$nf 门 FAIL）" })
if(-not $ReportPath){ $ReportPath=Join-Path $SkillDir 'verification-report-gates.md' }
[IO.File]::WriteAllText($ReportPath,($report -join "`n"),(New-Object System.Text.UTF8Encoding($true)))
"报告已写入: $ReportPath"
if($nf -gt 0){ exit 1 } else { exit 0 }
