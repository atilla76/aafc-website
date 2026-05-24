# AAFC panel - gorsel kart ekleme (CSS + html2canvas + loadFaceMaps)
# Calistir: panel.html ile ayni klasorde -> .\add_facecard.ps1
$ErrorActionPreference = "Stop"
$f = "panel.html"
$path = (Resolve-Path $f).Path
$c = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

# ---- 1) CSS (fmtot satirindan sonra) ----
$cssAnchor = ".fmtot{text-align:right;margin-top:8px;font-size:14px;font-weight:700;color:#B89A6A}"
$css = @"
.fmtot{text-align:right;margin-top:8px;font-size:14px;font-weight:700;color:#B89A6A}
.fmcard{position:relative;width:300px;max-width:100%;margin:8px auto;border-radius:10px;overflow:hidden;background:#0f0d17}
.fmcard img{width:100%;display:block}
.fmpin{position:absolute;width:22px;height:22px;border-radius:50%;transform:translate(-50%,-50%);display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;color:#fff;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,0.5)}
.fmleg{margin-top:6px}
.fmleg div{display:flex;align-items:center;gap:6px;font-size:12px;color:#F5F1EB;padding:2px 0}
.fmleg .dot{width:14px;height:14px;border-radius:50%;flex-shrink:0;border:1px solid #fff}
.fmdl{display:inline-block;margin-top:8px;padding:7px 14px;background:#B89A6A;color:#1C1929;border:none;border-radius:7px;font-size:13px;font-weight:600;cursor:pointer}
"@
if ($c.Contains($cssAnchor)) {
  $c = $c.Replace($cssAnchor, $css.TrimEnd())
  Write-Host "1) CSS eklendi" -ForegroundColor Green
} else { Write-Host "1) CSS ANCHOR YOK" -ForegroundColor Red; exit 1 }

# ---- 2) html2canvas (</head> oncesine) ----
$headAnchor = "</head>"
$scriptTag = @"
<script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
</head>
"@
$idx = $c.IndexOf($headAnchor)
if ($idx -ge 0) {
  $c = $c.Substring(0, $idx) + $scriptTag.TrimEnd() + $c.Substring($idx + $headAnchor.Length)
  Write-Host "2) html2canvas eklendi" -ForegroundColor Green
} else { Write-Host "2) HEAD YOK" -ForegroundColor Red; exit 1 }

# ---- 3) loadFaceMaps yeniden yaz (loadFaceMaps -> openAdd arasi) ----
$s = $c.IndexOf("async function loadFaceMaps")
$e = $c.IndexOf("function openAdd(){")
$newFn = @'
async function loadFaceMaps(visitId){
  document.getElementById('tpWrap').style.display='none';
  document.getElementById('imWrap').style.display='none';
  var mr=await db.from('injection_maps').select('*').eq('visit_id',visitId);
  if(!mr.data||!mr.data.length)return;
  for(var i=0;i<mr.data.length;i++){
    var m=mr.data[i];
    var pr=await db.from('injection_points').select('*').eq('map_id',m.id).order('seq');
    var pts2=pr.data||[];
    if(!pts2.length)continue;
    var isPlan=m.map_type==='treatment_plan';
    var cardId='fmc_'+m.id;
    var pins='';var leg='';var rows='';var total=0;
    pts2.forEach(function(p){
      var col=p.color||'#B8430F';
      var lx=(Number(p.x)*100).toFixed(2);
      var ly=(Number(p.y)*100).toFixed(2);
      pins+='<div class="fmpin" style="left:'+lx+'%;top:'+ly+'%;background:'+col+'">'+p.seq+'</div>';
      var dz=(p.descr||'');
      leg+='<div><span class="dot" style="background:'+col+'"></span><b>'+p.seq+'.</b> '+(p.product_name||'')+(dz?' - '+dz:'')+'</div>';
      var price=(p.price!=null)?p.price:null;
      if(price!=null)total+=Number(price);
      rows+='<tr><td class="fmn">'+p.seq+'</td><td class="fmp">'+(p.product_name||'')+'</td><td class="fmd">'+(p.descr||'')+'</td>';
      if(isPlan)rows+='<td class="fmpr">'+(price!=null?(price+(curSym()?' '+curSym():'')):'')+'</td>';
      rows+='</tr>';
    });
    var head=isPlan?'<tr><th>#</th><th>Procedure</th><th>Description</th><th>Price</th></tr>':'<tr><th>#</th><th>Procedure</th><th>Area</th></tr>';
    var tot=(isPlan&&total>0)?'<div class="fmtot">TOTAL: '+total+(curSym()?' '+curSym():'')+'</div>':'';
    var card='<div class="fmcard" id="'+cardId+'"><img src="face_template.jpeg" crossorigin="anonymous"/>'+pins+'</div>';
    var kind=isPlan?'tedavi_plani':'enjeksiyon';
    var btn='<button class="fmdl" onclick="dlFaceCard(this)" data-card="'+cardId+'" data-kind="'+kind+'">Indir (PNG)</button>';
    var html=card+'<div class="fmleg">'+leg+'</div><table class="fmt">'+head+rows+'</table>'+tot+btn;
    if(isPlan){document.getElementById('tpWrap').style.display='block';document.getElementById('tpBody').innerHTML=html;}
    else{document.getElementById('imWrap').style.display='block';document.getElementById('imBody').innerHTML=html;}
  }
}
function dlFaceCard(btn){
  var cardId=btn.getAttribute('data-card');
  var fn=btn.getAttribute('data-kind');
  var el=document.getElementById(cardId);
  if(!el||typeof html2canvas==='undefined'){alert('Indirme hazir degil, sayfayi yenileyin');return;}
  html2canvas(el,{backgroundColor:'#0f0d17',scale:2,useCORS:true}).then(function(canvas){
    var a=document.createElement('a');
    a.href=canvas.toDataURL('image/png');
    a.download='aafc_'+fn+'_'+new Date().toISOString().split('T')[0]+'.png';
    a.click();
  }).catch(function(err){alert('Indirme hatasi: '+err);});
}
'@
if ($s -ge 0 -and $e -gt $s) {
  $c = $c.Substring(0, $s) + $newFn.TrimEnd() + "`r`n" + $c.Substring($e)
  Write-Host "3) loadFaceMaps degistirildi" -ForegroundColor Green
} else { Write-Host "3) BLOK YOK s=$s e=$e" -ForegroundColor Red; exit 1 }

# ---- Kaydet (UTF-8 BOM'suz) ----
[System.IO.File]::WriteAllText($path, $c, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "TAMAM - panel.html guncellendi" -ForegroundColor Cyan
