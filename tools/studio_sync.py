"""Sincroniza os scripts do Studio com os arquivos nos DOIS sentidos, sem apagar trabalho de ninguém.

Projeto em dupla: o colaborador pode mexer do jeito que quiser (no Studio, à mão, com o Claude dele).
Lembra como cada script estava na última sincronização (_studio_base.json, por máquina) e decide sozinho:
  - só o Studio mudou  -> o texto do Studio vai para o arquivo (e daí para o GitHub pelo hook git-sync)
  - só o arquivo mudou -> o arquivo vai para o Studio
  - script novo no Studio -> vira arquivo; arquivo novo -> vira script no Studio
  - apagado de um lado e intacto do outro -> apaga do outro (cópia guardada em _studio_capturas/)
  - os DOIS mudaram (ou 1ª vez sem base e diferentes) -> CONFLITO: a versão do Studio vai para
    _studio_capturas/<data>/<arquivo>, nada é sobrescrito; junte no arquivo e rode `resolve <arquivo>`

Uso (da pasta do jogo):
  python tools/studio_sync.py            # sobe o servidor em 127.0.0.1:8771 e espera o Studio (até 180 s)
  depois, pelo MCP (execute_luau, Edit):
    loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8771/studio_sync.luau", true))()
  python tools/studio_sync.py resolve src/client/UI/Hud.luau   # depois de juntar um conflito
O resumo fica em _studio_sync_ultimo.txt.
"""

import json
import os
import sys
import threading
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BASE_FILE = os.path.join(GAME, "_studio_base.json")
SUMMARY = os.path.join(GAME, "_studio_sync_ultimo.txt")
CAPTURES = os.path.join(GAME, "_studio_capturas")
PORT = 8771
TIMEOUT = 180

EXT = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}
INIT = {"init.server.luau": "Script", "init.client.luau": "LocalScript", "init.luau": "ModuleScript"}


def h(text: bytes) -> int:
	# Mesmo hash do lado Luau (studio_sync.luau). \r fora: Windows x Studio.
	x = 0
	for c in text.replace(b"\r", b""):
		x = (x * 31 + c) % 2147483647
	return x


def roots():
	tree = json.load(open(os.path.join(GAME, "default.project.json"), encoding="utf-8"))["tree"]
	out = []

	def walk(node, path):
		for k, v in node.items():
			if k.startswith("$") or not isinstance(v, dict):
				continue
			if "$path" in v:
				out.append((v["$path"].replace("\\", "/").rstrip("/"), path + [k]))
			walk(v, path + [k])

	walk(tree, [])
	return out


def local_scripts():
	"""path(str 'A/B/C') -> {file, class, hash}"""
	res = {}
	for rel_root, inst in roots():
		top = os.path.join(GAME, rel_root)
		for d, _, files in os.walk(top):
			for f in files:
				if not f.endswith(".luau"):
					continue
				full = os.path.join(d, f)
				rel_dir = os.path.relpath(d, top).replace(os.sep, "/")
				parts = [] if rel_dir == "." else rel_dir.split("/")
				if f in INIT:
					cls, name_parts = INIT[f], parts
				elif f.endswith(".server.luau"):
					cls, name_parts = "Script", parts + [f[: -len(".server.luau")]]
				elif f.endswith(".client.luau"):
					cls, name_parts = "LocalScript", parts + [f[: -len(".client.luau")]]
				else:
					cls, name_parts = "ModuleScript", parts + [f[: -len(".luau")]]
				key = "/".join(inst + name_parts)
				res[key] = {
					"file": os.path.relpath(full, GAME).replace(os.sep, "/"),
					"class": cls,
					"hash": h(open(full, "rb").read()),
				}
	return res


def file_for_new(key, cls, local):
	"""Arquivo para um script que só existe no Studio. None se não der para mapear com segurança."""
	parts = key.split("/")
	for rel_root, inst in roots():
		if parts[: len(inst)] == inst and len(parts) > len(inst):
			sub = parts[len(inst) :]
			# pai é um script mapeado para arquivo único (X.luau)? não dá para virar pasta sozinho
			for i in range(1, len(sub)):
				if "/".join(inst + sub[:i]) in local:
					return None
			return "/".join([rel_root] + sub[:-1] + [sub[-1] + EXT[cls]])
	return None


def load_base():
	try:
		return json.load(open(BASE_FILE, encoding="utf-8"))
	except (OSError, ValueError):
		return {}


def save_base(base):
	with open(BASE_FILE, "w", encoding="utf-8", newline="\n") as f:
		json.dump(base, f, indent=0, sort_keys=True)


def write_file(rel, text):
	full = os.path.join(GAME, rel)
	os.makedirs(os.path.dirname(full), exist_ok=True)
	with open(full, "w", encoding="utf-8", newline="\n") as f:
		f.write(text.replace("\r", ""))


def capture(stamp, rel, text, tag=""):
	dest = os.path.join(CAPTURES, stamp, rel + tag)
	os.makedirs(os.path.dirname(dest), exist_ok=True)
	with open(dest, "w", encoding="utf-8", newline="\n") as f:
		f.write(text.replace("\r", ""))
	return os.path.relpath(dest, GAME).replace(os.sep, "/")


class State:
	plan_pushes = {}  # key -> hash enviado ao Studio (base só muda depois do ack)
	plan_deletes = {}
	log = []
	done = threading.Event()
	planned = False  # a /plan already ran in this run (see Handler.do_POST)
	plan_lock = threading.Lock()


def make_plan(studio):
	"""studio: {key: {class, hash, source?}}  (source só vem quando difere do arquivo)"""
	local = local_scripts()
	base = load_base()
	stamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
	ops, log = [], []

	for key in sorted(set(local) | set(studio) | set(base)):
		L = local.get(key)
		S = studio.get(key)
		B = base.get(key)
		lh = L and L["hash"]
		sh = S and S["hash"]

		if L and S and lh == sh:
			base[key] = lh
			continue
		if not L and not S:
			base.pop(key, None)
			continue

		studio_changed = sh != B
		file_changed = lh != B

		if S and not file_changed:  # só o Studio mudou (ou é novo no Studio)
			rel = L["file"] if L else file_for_new(key, S["class"], local)
			if rel is None:
				p = capture(stamp, key.replace("/", "_") + EXT[S["class"]], S["source"])
				log.append(f"CONFLITO script novo no Studio sem lugar certo nos arquivos: {key} -> {p}")
				continue
			write_file(rel, S["source"])
			base[key] = sh
			log.append(f"Studio -> arquivo: {rel}" + (" (novo)" if not L else ""))
		elif not S and not file_changed:  # apagado no Studio, arquivo intacto
			p = capture(stamp, L["file"], open(os.path.join(GAME, L["file"]), encoding="utf-8").read(), ".apagado")
			os.remove(os.path.join(GAME, L["file"]))
			base.pop(key, None)
			log.append(f"apagado no Studio -> arquivo removido: {L['file']} (cópia em {p})")
		elif L and not studio_changed:  # só o arquivo mudou (ou arquivo novo)
			text = open(os.path.join(GAME, L["file"]), encoding="utf-8").read()
			ops.append({"op": "write", "path": key.split("/"), "class": L["class"], "source": text})
			State.plan_pushes[key] = lh
			log.append(f"arquivo -> Studio: {L['file']}" + (" (novo)" if not S else ""))
		elif not L and not studio_changed:  # arquivo apagado, Studio intacto
			p = capture(stamp, key.replace("/", "_") + EXT[S["class"]], S["source"], ".apagado")
			ops.append({"op": "delete", "path": key.split("/")})
			State.plan_deletes[key] = True
			log.append(f"arquivo apagado -> script removido do Studio: {key} (cópia em {p})")
		else:  # os dois mudaram
			rel = (L and L["file"]) or file_for_new(key, S["class"], local) or key.replace("/", "_") + EXT[S["class"]]
			if S:
				p = capture(stamp, rel, S["source"], ".studio")
				log.append(f"CONFLITO (Studio e arquivo mudaram): {rel}. Versão do Studio em {p}. "
				           f"Junte no arquivo e rode: python tools/studio_sync.py resolve {rel}")
			else:
				log.append(f"CONFLITO: {rel} foi apagado no Studio mas mudou no arquivo. Arquivo mantido; "
				           f"se é para ficar, rode: python tools/studio_sync.py resolve {rel}")
			_conflicts = json.load(open(BASE_FILE + ".conflitos", encoding="utf-8")) if os.path.exists(BASE_FILE + ".conflitos") else {}
			_conflicts[rel] = {"key": key, "studio_hash": sh}
			with open(BASE_FILE + ".conflitos", "w", encoding="utf-8") as f:
				json.dump(_conflicts, f, indent=1)

	save_base(base)
	State.log = log
	return ops


def ack(ok_keys, failed):
	base = load_base()
	for key in ok_keys:
		if key in State.plan_pushes:
			base[key] = State.plan_pushes[key]
		elif key in State.plan_deletes:
			base.pop(key, None)
	save_base(base)
	for key, why in failed.items():
		State.log.append(f"FALHOU no Studio: {key} ({why})")
	summary = "\n".join(State.log) if State.log else "Studio e arquivos já iguais."
	with open(SUMMARY, "w", encoding="utf-8", newline="\n") as f:
		f.write(datetime.now().strftime("%d/%m %H:%M") + "\n" + summary + "\n")
	return summary


class Handler(BaseHTTPRequestHandler):
	def log_message(self, *a):
		pass

	def _send(self, code, body, ctype="application/json"):
		data = body.encode("utf-8")
		self.send_response(code)
		self.send_header("Content-Type", ctype)
		self.send_header("Content-Length", str(len(data)))
		self.end_headers()
		self.wfile.write(data)

	def do_GET(self):
		if self.path.startswith("/studio_sync.luau"):
			self._send(200, open(os.path.join(os.path.dirname(__file__), "studio_sync.luau"), encoding="utf-8").read(), "text/plain")
		elif self.path.startswith("/manifest"):
			local = local_scripts()
			self._send(200, json.dumps({"roots": [inst for _, inst in roots()], "hashes": {k: v["hash"] for k, v in local.items()}}))
		else:
			self._send(404, "{}")

	def do_POST(self):
		body = json.loads(self.rfile.read(int(self.headers["Content-Length"])).decode("utf-8"))
		try:
			if self.path.startswith("/plan"):
				# one plan per run: the MCP plugin sometimes runs the same execute_luau twice at once (seen 14/10
				# after a reconnect); two plans racing recorded a push in the base that the Studio never kept, and the
				# next run copied the old Studio scripts over the files. The repeat gets an error and writes nothing.
				with State.plan_lock:
					repeated = State.planned
					State.planned = True
				if repeated:
					self._send(200, json.dumps({"error": "pedido repetido nesta rodada (ignorado, nada mudou)"}))
					return
				self._send(200, json.dumps({"ops": make_plan(body["scripts"] or {})}))
			elif self.path.startswith("/ack"):
				failed = body.get("failed") or {}
				summary = ack(body.get("ok") or [], failed if isinstance(failed, dict) else {})
				self._send(200, json.dumps({"summary": summary}))
				State.done.set()
			else:
				self._send(404, "{}")
		except Exception as e:  # noqa: BLE001 - devolve o erro para o Studio ver
			self._send(500, json.dumps({"error": repr(e)}))
			State.done.set()


def serve():
	srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
	threading.Thread(target=srv.serve_forever, daemon=True).start()
	print(f"studio_sync: esperando o Studio em http://127.0.0.1:{PORT} (até {TIMEOUT}s)", flush=True)
	if State.done.wait(TIMEOUT):
		time.sleep(0.5)
		print(open(SUMMARY, encoding="utf-8").read() if os.path.exists(SUMMARY) else "erro (ver Studio)")
	else:
		print("studio_sync: o Studio não chamou a tempo; nada mudou.")
	srv.shutdown()


def resolve(rel):
	rel = rel.replace("\\", "/")
	path = BASE_FILE + ".conflitos"
	conflicts = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
	if rel not in conflicts:
		sys.exit(f"{rel} não está na lista de conflitos ({path}).")
	c = conflicts.pop(rel)
	base = load_base()
	# base = versão do Studio: na próxima sincronização o arquivo (já juntado) vai para o Studio
	if c["studio_hash"] is None:
		base.pop(c["key"], None)
	else:
		base[c["key"]] = c["studio_hash"]
	save_base(base)
	with open(path, "w", encoding="utf-8") as f:
		json.dump(conflicts, f, indent=1)
	print(f"ok: {rel} resolvido; rode a sincronização de novo para levar o arquivo ao Studio.")


if __name__ == "__main__":
	if len(sys.argv) >= 3 and sys.argv[1] == "resolve":
		resolve(sys.argv[2])
	elif len(sys.argv) >= 2 and sys.argv[1] == "--sem-studio":
		# Studio fechado: não há o que proteger agora; libera a trava por 15 min
		with open(SUMMARY, "w", encoding="utf-8", newline="\n") as f:
			f.write(datetime.now().strftime("%d/%m %H:%M") + "\nsem Studio aberto: sincronização pulada\n")
		print("ok: sem Studio, trava liberada por 15 min.")
	else:
		serve()
