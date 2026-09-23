// PATO Desempenho — API de compartilhamento por código de 6 dígitos
// Zero dependências — roda com Node.js puro (v18+)
// Uso: node server.js

const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT         = 3000;
const DATA_FILE    = path.join(__dirname, 'shares.json');
const EXPIRY_HOURS = 48;
const MAX_BODY     = 2 * 1024 * 1024; // 2 MB

function loadData(){
  try{ return JSON.parse(fs.readFileSync(DATA_FILE,'utf8')); }
  catch{ return {}; }
}
function saveData(data){
  fs.writeFileSync(DATA_FILE, JSON.stringify(data));
}

function cleanup(data){
  const limit = EXPIRY_HOURS * 3600000;
  const now   = Date.now();
  for(const k in data) if(now - data[k].ts > limit) delete data[k];
  return data;
}

function genCode(data){
  for(let i=0;i<100;i++){
    const c = String(Math.floor(100000 + Math.random()*900000));
    if(!data[c]) return c;
  }
  return null;
}

function parseBody(req){
  return new Promise((resolve,reject)=>{
    let body='';
    req.on('data', chunk=>{
      body+=chunk;
      if(body.length>MAX_BODY){ reject('payload too large'); req.destroy(); }
    });
    req.on('end', ()=>{
      try{ resolve(JSON.parse(body)); }catch{ reject('json inválido'); }
    });
    req.on('error', reject);
  });
}

function json(res, status, obj){
  res.writeHead(status,{'Content-Type':'application/json'});
  res.end(JSON.stringify(obj));
}

const server = http.createServer(async(req,res)=>{
  res.setHeader('Access-Control-Allow-Origin','*');
  res.setHeader('Access-Control-Allow-Methods','GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers','Content-Type');
  if(req.method==='OPTIONS'){ res.writeHead(204); res.end(); return; }

  const url = new URL(req.url, 'http://localhost');

  // POST /api/share — cria compartilhamento, retorna código
  if(req.method==='POST' && url.pathname==='/api/share'){
    try{
      const body = await parseBody(req);
      if(!body || !body.contrato) return json(res,400,{error:'Payload inválido'});
      const data = cleanup(loadData());
      const code = genCode(data);
      if(!code) return json(res,503,{error:'Muitos códigos ativos. Tente novamente.'});
      data[code] = { dados:body, ts:Date.now() };
      saveData(data);
      console.log(`[SHARE] código ${code} criado`);
      json(res,200,{codigo:code});
    }catch(e){
      json(res,400,{error:String(e)});
    }
    return;
  }

  // GET /api/share/:code — busca por código
  const m = url.pathname.match(/^\/api\/share\/(\d{6})$/);
  if(req.method==='GET' && m){
    const data = cleanup(loadData());
    const entry = data[m[1]];
    if(!entry) return json(res,404,{error:'Código não encontrado ou expirado'});
    console.log(`[GET] código ${m[1]} consultado`);
    json(res,200,entry.dados);
    return;
  }

  // Health check
  if(url.pathname==='/api/health'){
    json(res,200,{status:'ok',shares:Object.keys(cleanup(loadData())).length});
    return;
  }

  json(res,404,{error:'Not found'});
});

server.listen(PORT, ()=>{
  console.log(`PATO API rodando em http://localhost:${PORT}`);
  console.log(`Endpoints:`);
  console.log(`  POST /api/share       → cria código`);
  console.log(`  GET  /api/share/:code  → busca por código`);
  console.log(`  GET  /api/health       → status`);
});
