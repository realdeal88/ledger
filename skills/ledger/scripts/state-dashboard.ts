#!/usr/bin/env bun
/**
 * state-dashboard.ts — render a project's living files into one self-contained HTML view.
 *
 *   bun state-dashboard.ts <project-dir>
 *
 * Reads GOALS/TRACKER/SESSION/DECISIONS/MISTAKES/LOG (whichever exist) and writes
 * <project-dir>/.claude/state.html — a warm, editorial dashboard in the Anthropic
 * aesthetic: sprint goal + progress, a task board, the exact next step, recent
 * decisions/mistakes/log, and a graph laddering active work up to the sprint goal.
 * Markdown stays the source of truth; this is a derived view, regenerated on checkpoint
 * and (debounced) on living-file edits.
 */
import { readFileSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join, basename } from "node:path";

const dir = process.argv[2] || process.cwd();
const read = (f: string): string => {
  try { return existsSync(join(dir, f)) ? readFileSync(join(dir, f), "utf8") : ""; }
  catch { return ""; }
};

const goals = read("GOALS.md");
const tracker = read("TRACKER.md");
const session = read("SESSION.md");
const decisions = read("DECISIONS.md");
const mistakes = read("MISTAKES.md");
const log = read("LOG.md");

if (!tracker && !goals && !session) process.exit(0); // not a living-file project

const esc = (s: string): string =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const oneLine = (s: string, n = 116): string => {
  const t = s.replace(/\s+/g, " ").trim();
  return t.length > n ? t.slice(0, n - 1) + "…" : t;
};

const project =
  (goals.match(/^#\s*GOALS\s*[—-]\s*(.+)$/m)?.[1] ||
   session.match(/^project:\s*(.+)$/m)?.[1] ||
   basename(dir)).trim();

const sprintGoal =
  (goals.match(/##\s*Current sprint[\s\S]*?Goal:\s*(.+)/i)?.[1] ||
   goals.match(/##\s*North star\s*\n+([^\n#].*)/i)?.[1] || "").trim();

const lastTopic = (session.match(/^session_topic:\s*(.+)$/m)?.[1] || "").trim();
const lastTime = (session.match(/^handoff_time:\s*(.+)$/m)?.[1] || "").trim();

const nextStep = (() => {
  const m = session.match(/##\s*Exact Next Step\s*\n([\s\S]*?)(?:\n##\s|\n<!--|$)/i);
  return m ? m[1].trim().split("\n").map((l) => l.trim()).filter(Boolean).slice(0, 5).join("\n") : "";
})();

// ── Tasks ──
type Task = { status: string; text: string };
const STATUS: Record<string, { label: string; cls: string }> = {
  "~": { label: "In progress", cls: "prog" },
  " ": { label: "To do", cls: "todo" },
  "!": { label: "Blocked", cls: "block" },
  x: { label: "Done", cls: "done" },
  "-": { label: "Deferred", cls: "defer" },
};
const tasks: Task[] = [];
for (const line of tracker.split("\n")) {
  const m = line.match(/^\s*[-*]\s*\[([ x~!\-])\]\s*(.+)$/);
  if (m) tasks.push({ status: m[1], text: m[2].trim() });
}
const byStatus = (s: string) => tasks.filter((t) => t.status === s);

// ── Goal must-haves (progress) ──
const mh = [...goals.matchAll(/^\s*[-*]\s*\[([ x])\]\s*(.+)$/gm)].map((m) => ({
  done: m[1] === "x", text: m[2].trim(),
}));
const mhDone = mh.filter((m) => m.done).length;
const mhPct = mh.length ? Math.round((mhDone / mh.length) * 100) : 0;

const headings = (md: string, n: number): string[] =>
  [...md.matchAll(/^##\s+(.+)$/gm)].map((m) => m[1].trim()).slice(-n).reverse();
const recentDecisions = headings(decisions, 6);
const recentMistakes = headings(mistakes, 5);
const recentLog = headings(log, 6);

// ── Mermaid: ladder active work to the sprint goal ──
const mmId = (s: string) => "n" + Math.abs([...s].reduce((a, c) => (a * 31 + c.charCodeAt(0)) | 0, 7)).toString(36);
const mmLabel = (s: string) => '"' + oneLine(s, 40).replace(/"/g, "'") + '"';
let mermaid = "";
const active = [...byStatus("~"), ...byStatus("!")].slice(0, 8);
if (active.length) {
  const lines = [`  GOAL[${mmLabel(sprintGoal || project)}]:::goal`];
  for (const t of active) {
    const id = mmId(t.text);
    lines.push(`  ${id}[${mmLabel(t.text)}]:::${t.status === "!" ? "block" : "prog"}`);
    lines.push(`  GOAL --> ${id}`);
  }
  mermaid = "graph LR\n" + lines.join("\n") +
    "\n  classDef goal fill:#c96442,stroke:#c96442,color:#fff;" +
    "\n  classDef prog fill:#f4e8d8,stroke:#bf8a3d,color:#6b4e1f;" +
    "\n  classDef block fill:#f6e3dd,stroke:#bb5a44,color:#6e2c20;";
}

const col = (s: string, t: Task[]) =>
  t.length
    ? `<div class="col"><h3 class="${STATUS[s].cls}">${STATUS[s].label}<span>${t.length}</span></h3>` +
      t.map((x) => `<div class="card ${STATUS[s].cls}">${esc(oneLine(x.text))}</div>`).join("") + `</div>`
    : `<div class="col"><h3 class="${STATUS[s].cls}">${STATUS[s].label}<span>0</span></h3><div class="card empty">—</div></div>`;

const list = (items: string[], cls: string) =>
  items.length ? items.map((i) => `<li class="${cls}">${esc(oneLine(i, 96))}</li>`).join("") : `<li class="empty">none yet</li>`;

const now = new Date().toISOString().replace("T", " ").slice(0, 16) + "Z";

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(project)} — ledger</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Ccircle cx='16' cy='16' r='13' fill='%23c96442'/%3E%3C/svg%3E">
<style>
:root{
  --bg:#faf9f5;--surface:#ffffff;--inset:#f4f2ea;--line:#e7e3d8;--line2:#efece2;
  --ink:#2b2824;--ink2:#4a463f;--mut:#8c877c;--accent:#c96442;--accent-soft:#f0e0d4;
  --todo:#9b9488;--prog:#bf8a3d;--done:#6f8f5f;--block:#bb5a44;--defer:#aaa498;
  --serif:ui-serif,"Iowan Old Style","Palatino Linotype",Palatino,Georgia,"Times New Roman",serif;
  --sans:ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",Inter,system-ui,sans-serif;
}
*{box-sizing:border-box}
html{background:var(--bg)}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.6 var(--sans);-webkit-font-smoothing:antialiased}
.wrap{max-width:1080px;margin:0 auto;padding:44px 28px 72px}
header{display:flex;align-items:center;gap:13px;margin-bottom:5px}
h1{font-family:var(--serif);font-size:32px;font-weight:600;margin:0;letter-spacing:-.01em;color:var(--ink)}
.pill{font-size:11.5px;font-weight:600;letter-spacing:.04em;color:#fff;background:var(--accent);border-radius:999px;padding:3px 11px;text-transform:lowercase}
.sub{color:var(--mut);font-size:13px;margin:0 0 30px}
.grid{display:grid;grid-template-columns:1.1fr 1fr;gap:18px}
@media(max-width:780px){.grid{grid-template-columns:1fr}}
.panel{background:var(--surface);border:1px solid var(--line);border-radius:16px;padding:22px 24px;box-shadow:0 1px 2px rgba(60,50,40,.03)}
.panel h2{font-size:11.5px;text-transform:uppercase;letter-spacing:.1em;color:var(--mut);margin:0 0 16px;font-weight:600}
.goal{font-family:var(--serif);font-size:20px;line-height:1.4;margin:0 0 18px;color:var(--ink)}
.goal.none{font-family:var(--sans);font-size:15px;color:var(--mut)}
.bar{height:7px;background:var(--inset);border-radius:99px;overflow:hidden}
.bar>i{display:block;height:100%;background:linear-gradient(90deg,var(--accent),#e0936f);border-radius:99px}
.bar-meta{display:flex;justify-content:space-between;color:var(--mut);font-size:12.5px;margin-top:9px}
ul.mh{list-style:none;margin:16px 0 0;padding:0}
ul.mh li{padding:6px 0 6px 28px;position:relative;font-size:14px;color:var(--ink2)}
ul.mh li:before{content:"";position:absolute;left:0;top:7px;width:16px;height:16px;border-radius:5px;border:1.5px solid var(--line);background:#fff}
ul.mh li.d{color:var(--mut);text-decoration:line-through;text-decoration-color:var(--line)}
ul.mh li.d:before{background:var(--done);border-color:var(--done)}
ul.mh li.d:after{content:"✓";position:absolute;left:3px;top:6px;font-size:10px;color:#fff;font-weight:700}
pre.next{white-space:pre-wrap;word-break:break-word;background:var(--inset);border:1px solid var(--line2);border-radius:12px;padding:15px 16px;font-size:13.5px;margin:0;line-height:1.55;color:var(--ink2);font-family:var(--sans)}
.board{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-top:2px}
@media(max-width:780px){.board{grid-template-columns:1fr 1fr}}
.col h3{font-size:11.5px;margin:0 0 11px;display:flex;align-items:center;gap:8px;text-transform:uppercase;letter-spacing:.06em;font-weight:600}
.col h3 span{background:var(--inset);border-radius:99px;padding:1px 8px;font-size:11px;color:var(--mut)}
.col h3.todo{color:var(--todo)}.col h3.prog{color:var(--prog)}.col h3.done{color:var(--done)}.col h3.block{color:var(--block)}.col h3.defer{color:var(--defer)}
.card{background:var(--surface);border:1px solid var(--line);border-left:3px solid var(--todo);border-radius:9px;padding:10px 12px;font-size:13px;margin-bottom:9px;line-height:1.45;color:var(--ink2)}
.card.prog{border-left-color:var(--prog)}.card.done{border-left-color:var(--done);color:var(--mut)}.card.block{border-left-color:var(--block)}.card.defer{border-left-color:var(--defer);color:var(--mut)}
.card.empty{border-left-color:var(--line);color:var(--mut);text-align:center}
ul.tl{list-style:none;margin:0;padding:0}
ul.tl li{padding:9px 0 9px 18px;position:relative;font-size:13.5px;border-bottom:1px solid var(--line2);color:var(--ink2)}
ul.tl li:last-child{border-bottom:0}
ul.tl li:before{content:"";position:absolute;left:0;top:15px;width:6px;height:6px;border-radius:99px;background:var(--accent)}
ul.tl li.mis:before{background:var(--block)}
ul.tl li.empty{color:var(--mut)}ul.tl li.empty:before{background:var(--line)}
.full{grid-column:1/-1}
.mermaid{background:var(--inset);border:1px solid var(--line2);border-radius:12px;padding:20px;text-align:center}
footer{color:var(--mut);font-size:12px;margin-top:30px;text-align:center;font-family:var(--serif);font-style:italic}
footer code{font-family:var(--sans);font-style:normal;color:var(--accent)}
</style></head>
<body><div class="wrap">
<header><h1>${esc(project)}</h1><span class="pill">ledger</span></header>
<p class="sub">${lastTopic ? "Last session: " + esc(lastTopic) + " &middot; " : ""}${lastTime ? "snapshot " + esc(lastTime) + " &middot; " : ""}generated ${now}</p>

<div class="grid">
  <div class="panel">
    <h2>Sprint goal</h2>
    <p class="goal${sprintGoal ? "" : " none"}">${sprintGoal ? esc(sprintGoal) : "No sprint goal set in GOALS.md"}</p>
    ${mh.length ? `<div class="bar"><i style="width:${mhPct}%"></i></div>
    <div class="bar-meta"><span>${mhDone} of ${mh.length} must-haves</span><span>${mhPct}%</span></div>
    <ul class="mh">${mh.map((m) => `<li class="${m.done ? "d" : ""}">${esc(oneLine(m.text))}</li>`).join("")}</ul>` : ""}
  </div>
  <div class="panel">
    <h2>Exact next step</h2>
    ${nextStep ? `<pre class="next">${esc(nextStep)}</pre>` : '<p style="color:var(--mut)">No SESSION.md next step captured yet — run /ledger.</p>'}
  </div>
</div>

<div class="panel full" style="margin-top:18px">
  <h2>Task board</h2>
  <div class="board">
    ${col("~", byStatus("~"))}
    ${col(" ", byStatus(" "))}
    ${col("!", byStatus("!"))}
    ${col("x", byStatus("x").slice(-6))}
  </div>
</div>

${mermaid ? `<div class="panel full" style="margin-top:18px"><h2>Active work &rarr; sprint goal</h2><div class="mermaid">${mermaid}</div></div>` : ""}

<div class="grid" style="margin-top:18px">
  <div class="panel"><h2>Recent decisions</h2><ul class="tl">${list(recentDecisions, "dec")}</ul></div>
  <div class="panel"><h2>Recent mistakes</h2><ul class="tl">${list(recentMistakes, "mis")}</ul></div>
</div>

<div class="panel full" style="margin-top:18px"><h2>Recent activity</h2><ul class="tl">${list(recentLog, "log")}</ul></div>

<footer>Markdown is the source of truth &mdash; regenerated by <code>ledger</code> on checkpoint &amp; living-file edits.</footer>
</div>
${mermaid ? `<script type="module">import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";mermaid.initialize({startOnLoad:true,theme:"neutral",themeVariables:{fontFamily:"ui-sans-serif,system-ui,sans-serif",lineColor:"#b8b1a3",mainBkg:"#ffffff"}});</script>` : ""}
</body></html>`;

const outDir = join(dir, ".claude");
if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "state.html"), html);

// The dashboard is derived (Markdown is the source of truth) — keep it out of git so it
// never shows as a perpetual diff. Idempotent: only writes the ignore line if missing.
const ignorePath = join(outDir, ".gitignore");
const ignored = existsSync(ignorePath) ? readFileSync(ignorePath, "utf8") : "";
if (!ignored.split("\n").some((l) => l.trim() === "state.html")) {
  writeFileSync(ignorePath, (ignored && !ignored.endsWith("\n") ? ignored + "\n" : ignored) + "state.html\n");
}

console.log(`ledger: wrote ${join(outDir, "state.html")} (${tasks.length} tasks, ${mh.length} must-haves)`);
