"""Windows x64 AoE3 DE read-only collector. Python standard library only.
Does not launch games, access the network, patch memory, or change game files.
Run --help for options. Output mapped.bin is an RVA-indexed analysis image,
not a runnable replacement executable. Uncaptured sections are zero-filled.
"""
import argparse,ctypes as C,ctypes.wintypes as W,datetime,hashlib,json,pathlib,shutil,struct,sys,time

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()

def pe_info(path):
 with path.open('rb') as f:
  header=f.read(4096)
  assert header[:2]==b'MZ','Not a PE executable'
  off=struct.unpack_from('<I',header,0x3c)[0]
  f.seek(off);h=f.read(24)
  assert h[:4]==b'PE\0\0','Bad PE signature'
  machine,nsects,timestamp,_,_,optsize,_=struct.unpack_from('<HHIIIHH',h,4)
  opt=f.read(optsize)
  assert machine==0x8664 and struct.unpack_from('<H',opt)[0]==0x20b,'Requires x64 PE32+'
  size,headers=struct.unpack_from('<II',opt,56)
  sections=[]
  for _ in range(nsects):
   s=f.read(40);name=s[:8].rstrip(b'\0').decode('ascii',errors='replace')
   virtual_size,rva,raw_size=struct.unpack_from('<III',s,8)
   flags=struct.unpack_from('<I',s,36)[0]
   sections.append(dict(name=name,rva=rva,virtual_size=virtual_size,raw_size=raw_size,flags=flags))
  return dict(size=size,headers=headers,timestamp=timestamp,sections=sections)

def capture(args):
 if sys.platform!='win32' or C.sizeof(C.c_void_p)!=8:raise RuntimeError('Use 64-bit Python on Windows')
 k=C.WinDLL('kernel32',use_last_error=True);ps=C.WinDLL('psapi',use_last_error=True)
 k.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];k.OpenProcess.restype=W.HANDLE
 k.CloseHandle.argtypes=[W.HANDLE]
 k.QueryFullProcessImageNameW.argtypes=[W.HANDLE,W.DWORD,W.LPWSTR,C.POINTER(W.DWORD)]
 ps.EnumProcesses.argtypes=[C.POINTER(W.DWORD),W.DWORD,C.POINTER(W.DWORD)]
 ps.EnumProcessModules.argtypes=[W.HANDLE,C.POINTER(W.HMODULE),W.DWORD,C.POINTER(W.DWORD)]
 k.ReadProcessMemory.argtypes=[W.HANDLE,C.c_void_p,C.c_void_p,C.c_size_t,C.POINTER(C.c_size_t)]
 def locate():
  ids=(W.DWORD*16384)();used=W.DWORD()
  if not ps.EnumProcesses(ids,C.sizeof(ids),C.byref(used)):raise C.WinError(C.get_last_error())
  found=[]
  for pid in ids[:used.value//4]:
   if args.pid and pid!=args.pid:continue
   h=k.OpenProcess(0x1000,False,pid)
   if not h:continue
   try:
    buf=C.create_unicode_buffer(32768);n=W.DWORD(len(buf))
    if k.QueryFullProcessImageNameW(h,0,buf,C.byref(n)) and pathlib.Path(buf.value).name.lower()=='aoe3de_s.exe':found.append((pid,pathlib.Path(buf.value)))
   finally:k.CloseHandle(h)
  return found
 deadline=time.monotonic()+args.wait
 while True:
  found=locate()
  if len(found)>1:raise RuntimeError('Multiple games found; rerun with --pid PID')
  if found:break
  if time.monotonic()>=deadline:raise RuntimeError('No running AoE3DE_s.exe found. Start it OFFLINE and rerun, or use --wait 900')
  print('Waiting for offline game...',flush=True);time.sleep(5)
 pid,exe=found[0]
 if args.delay:print(f'Found PID {pid}. Waiting {args.delay}s for startup.',flush=True);time.sleep(args.delay)
 if args.prompt:input('When the OFFLINE game is at the main menu or paused test, press Enter here: ')
 info=pe_info(exe);out=pathlib.Path(args.out).resolve()
 if out.exists():raise RuntimeError('Output folder already exists. Choose a new --out folder; nothing was overwritten.')
 out.mkdir(parents=True)
 h=k.OpenProcess(0x410,False,pid)
 if not h:raise C.WinError(C.get_last_error())
 try:
  modules=(W.HMODULE*2048)();needed=W.DWORD()
  if not ps.EnumProcessModules(h,modules,C.sizeof(modules),C.byref(needed)):raise C.WinError(C.get_last_error())
  base=modules[0];data=bytearray(info['size']);fail=[]
  ranges=[(0,info['headers'])]+[(s['rva'],max(s['virtual_size'],s['raw_size'])) for s in info['sections'] if s['flags']&0x20000000 or s['name'] in ('.rdata','.pdata','_RDATA')]
  for start,length in ranges:
   for pos in range(start,min(start+length,len(data)),4096):
    n=min(4096,start+length-pos,len(data)-pos);buf=C.create_string_buffer(n);got=C.c_size_t()
    ok=k.ReadProcessMemory(h,base+pos,buf,n,C.byref(got))
    data[pos:pos+got.value]=buf.raw[:got.value]
    if not ok or got.value!=n:fail.append(dict(rva=pos,requested=n,read=got.value,error=C.get_last_error()))
  (out/'legacy.mapped.bin').write_bytes(data)
 finally:k.CloseHandle(h)
 shutil.copy2(exe,out/'legacy.disk.exe')
 original_hash=sha(exe)
 if sha(out/'legacy.disk.exe')!=original_hash:raise RuntimeError('Executable copy hash mismatch')
 meta=dict(captured_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),pid=pid,path=str(exe),base=base,base_hex=hex(base),size=info['size'],disk_sha256=original_hash,mapped_sha256=sha(out/'legacy.mapped.bin'),reported_version=args.version,offline_status='User must ensure offline operation; this script does not change or verify networking',sections=info['sections'],ranges=ranges,read_failures=fail)
 (out/'legacy.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
 install=exe.parent;inventory=[]
 for p in sorted((install/'Game').rglob('*.bar')):
  stat=p.stat();inventory.append(dict(path=str(p.relative_to(install)),size=stat.st_size,modified_utc=datetime.datetime.fromtimestamp(stat.st_mtime,datetime.timezone.utc).isoformat()))
 (out/'archive-inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')
 if args.copy_data:
  for p in (install/'Game').rglob('*.bar'):
   if p.name.lower() not in ('data.bar','artterrain.bar'):continue
   dest=out/'matching-data'/p.relative_to(install);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
   digest=sha(p)
   if sha(dest)!=digest:raise RuntimeError(f'Data copy mismatch: {p}')
   for item in inventory:
    if item['path']==str(p.relative_to(install)):item['sha256']=digest
  (out/'archive-inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')
 manifest=install.parent.parent/'appmanifest_933110.acf'
 if manifest.exists():shutil.copy2(manifest,out/'appmanifest_933110.acf')
 results={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file()}
 (out/'SHA256SUMS.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
 print(json.dumps(dict(output=str(out),pid=pid,base=hex(base),size=info['size'],disk_sha256=original_hash,read_failure_count=len(fail)),indent=2),flush=True)
 if fail:raise RuntimeError('Capture is partial; preserve output and report unreadable ranges. Do not claim success.')

if __name__=='__main__':
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--out',help='New output directory (must not exist)')
 ap.add_argument('--pid',type=int,help='Optional exact running game PID')
 ap.add_argument('--wait',type=int,default=0,help='Seconds to wait for offline game to start')
 ap.add_argument('--delay',type=int,default=0,help='Seconds to wait after finding process')
 ap.add_argument('--prompt',action='store_true',help='Wait for Enter once game is ready')
 ap.add_argument('--copy-data',action='store_true',help='Copy matching Data.bar and ArtTerrain.bar, with hashes')
 ap.add_argument('--version',default='not recorded',help='Version shown by game or file properties')
 ap.add_argument('--inspect-pe',help='Test PE parser on a disk executable only; no game launch or capture')
 a=ap.parse_args()
 try:
  if a.inspect_pe:print(json.dumps(pe_info(pathlib.Path(a.inspect_pe)),indent=2))
  elif not a.out:ap.error('--out is required unless --inspect-pe is used')
  else:capture(a)
 except Exception as e:print('ERROR:',e,file=sys.stderr);sys.exit(1)
