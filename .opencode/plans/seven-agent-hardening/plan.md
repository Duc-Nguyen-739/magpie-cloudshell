# Củng cố pipeline 7 agent — hai đợt kỹ thuật

- Slug: `seven-agent-hardening`
- Ngày: 2026-11-20
- Project root: `/home/caigicungdc98/magpie-cloudshell`
- Trạng thái: IMPLEMENTED — test offline + live pass; đã áp live 7 profile, API
  OpenCode xác nhận; backup và temp test đã xóa theo yêu cầu user sau khi kiểm xong
- Loại task: CHANGE; profile plan: STANDARD (hướng này đã được user duyệt)
- User: “Duyệt. Lệ plan chi tiết về mặt kỹ thuật cả 2 đợt. Sau đó triển khai sửa cho tôi.”
- Quyền đã duyệt: lập plan, sửa bộ 7 agent và phần hỗ trợ, kiểm thử, áp dụng bảy profile trên máy với backup. Không commit/push/deploy, không đổi group/provider/model/tài khoản, không restart service, không xóa plan.
- Baseline của công việc có sẵn: `/tmp/opencode/agents-audit-v2-baseline/` (manifest, bản file, working.patch, index.patch, HEAD). Index ban đầu rỗng. Không dùng HEAD để thay thế file đang bẩn. **Baseline, backup và temp test đã được xóa sau khi user yêu cầu dọn.**

## 1. Mục tiêu

User có bảy agent đúng vai, không tự triển khai khi chỉ được hỏi, không tuyên bố đạt khi thiếu kiểm chứng, không tự commit hay xóa hồ sơ, và có cơ chế cập nhật profile an toàn. Đợt 1 sửa các mâu thuẫn/quyền; đợt 2 giảm lặp và bổ sung kiểm tra hồi quy. Phân biệt policy công cụ được OpenCode thực thi với quy ước cần orchestration/sandbox: không hứa shell/test chạy trên host là sandbox.

Yêu cầu nghiệm thu:

| R | Nội dung | Đợt |
|---|---|---|
| R1 | Giữ 7 ID, mode và model binding; Description ngắn, đúng vai | 1 |
| R2 | Permissions V2 tối thiểu theo vai, xét shell/MCP/Code Mode/plugin và giới hạn thực tế | 1 |
| R3 | CONSULT/PLAN/CHANGE/RELEASE; đồng thuận theo task; không giả định “Nhóm A” | 1 |
| R4 | Session mới/lượt; ledger execution; không poll; khóa group và năng lực provider; retry thống nhất | 1 |
| R5 | Coverage R/AC theo vai; PASS/FAIL/BLOCKED/N/A; ba tester mặc định, không hạ cổng vì quota | 1 |
| R6 | Ownership test theo framework; không chạy trên tập file đang đổi; fingerprint và cách ly tài nguyên | 1–2 |
| R7 | Baseline dirty/index; commit đúng phần đã duyệt; giữ plan mặc định; approval riêng release | 1 |
| R8 | Plan pending/applied/partial/blocked; sửa nhỏ vs đổi hướng; không hợp thức hóa code sai | 1 |
| R9 | Skills khả dụng, required/optional, ngoại lệ nhất quán; MCP/capability động | 1–2 |
| R10 | Prompt gọn; plan STANDARD/STRICT; không từ-cấm máy móc; artifact thay output dài | 2 |
| R11 | UI theo ảnh hưởng, khóa browser, fallback đủ quyền, mutation chỉ test đã cho phép | 2 |
| R12 | Kiểm tra tự động có ca âm; scenario eval có giới hạn công bố; safe sync và kiểm API runtime | 1–2 |

## 2. Phạm vi

File nguồn dự kiến sửa:

- `/home/caigicungdc98/magpie-cloudshell/config/agents/{leader,review,reviewplan,coder,tester,tester2,tester3}.md`: cả 7 Description/body/frontmatter; giữ binding model/mode.
- `/home/caigicungdc98/magpie-cloudshell/AGENTS.md`: chỉ các đoạn mô tả pipeline/skill/session/MCP liên quan; giữ nguyên phần cài đặt/provider và thay đổi có sẵn không liên quan.
- `/home/caigicungdc98/magpie-cloudshell/docs/leader.md`: runbook mới, state/coverage/handoff/approval/counters, sources và giới hạn.
- `/home/caigicungdc98/magpie-cloudshell/docs/opencode.md`: các mục agent/skills/reload/update; bảo toàn hướng dẫn MCP headless đang có.
- `/home/caigicungdc98/magpie-cloudshell/scripts/setup-opencode.sh`: nối installer theo hướng non-destructive; không tự cập nhật profile đã có hoặc reset nhóm.
- `/home/caigicungdc98/magpie-cloudshell/scripts/doctor.sh`: chỉ thêm kiểm tra profile/offline khi phù hợp; giữ sửa SIGPIPE của user.

File mới dự kiến (tên có thể thu gọn sau kiểm plan, không thêm dependency):

- `/home/caigicungdc98/magpie-cloudshell/config/agent-contract.json`: version, IDs/modes/bindings, statuses/counters, role capabilities, ví dụ scenario có cấu trúc; không chứa secret/instance state.
- `/home/caigicungdc98/magpie-cloudshell/scripts/lib/agent-profiles.mjs`: parse tập con frontmatter do repo quản lý, validate policy/contract, evaluator wildcard-last-match dùng cho test offline (không giả runtime Core).
- `/home/caigicungdc98/magpie-cloudshell/scripts/check-agents.mjs`: lint read-only profile/contract và kiểm consistency; exit 0/1, có thư mục kiểm thử chỉ định.
- `/home/caigicungdc98/magpie-cloudshell/scripts/sync-agents.mjs`: dry-run/check/apply hoặc install-missing, expected-hash và backup, agents-only; không gọi magpie/MCP/restart.
- `/home/caigicungdc98/magpie-cloudshell/tests/agents.test.mjs`: unit/regression/negative policy và parser.
- `/home/caigicungdc98/magpie-cloudshell/tests/sync-agents.test.mjs`: installer fixture với HOME/config giả lập, không đụng profile thật.
- `/home/caigicungdc98/magpie-cloudshell/tests/fixtures/agent-scenarios.json`: các ca orchestration và expected outcomes; ca chưa chạy với LLM không được báo như live eval.

Đích áp dụng máy: bảy file `/home/caigicungdc98/.config/opencode/agents/*.md` tương ứng, chỉ sau hoàn tất test/audit, qua updater có hash-guard/backup. Không sửa `~/.config/magpie`, settings/model OpenChamber hay OpenCode JSONC. Thư mục plan này được giữ lại.

## 3. Hiện trạng kỹ thuật

### 3.1 Môi trường

- Repo bash + Node ES modules, chưa có test runner/manifest/CI chung; dùng Node built-in `node:test` và `node:assert/strict`, không npm install.
- OpenCode v2.3.2. Official docs: `https://opencode.ai/docs/agents`, `/permissions`, `/skills`, `/config`, `/api`.
- OpenCode API dùng CLI authenticated context: `opencode api get /api/agent` và `/api/skill`; response CLI có envelope `{ location, data }`.
- Rules ordered, last-match-wins; custom agents kế thừa policy mặc định allow. Shell có authority host; edit deny không khóa shell. MCP action normalize server/tool bằng `_`. Deny execute không phải cấp quyền nested tool.

### 3.2 Baseline đã đọc/kiểm

- Cả 7 bản repo == installed == system/description API trước task.
- `config/agents/leader.md:99–103` session mới trái `:272` cùng phiên; `:636–655` vs `:689` thiếu chuẩn tester.
- `config/agents/review.md:203–213` plan chứa toàn implementation; `:374–383` cấm token `...` cả code.
- `config/agents/reviewplan.md:179–186` preconditions không xét partial apply; `:99–103` UI audit read-only.
- `config/agents/tester*.md` chỉ deny subagent/question; lời cấm sửa source không được edit permission thực thi.
- `config/agents/coder.md:148` “Leader sẽ đọc lại code” sai vai.
- `scripts/setup-opencode.sh:27–53` copy chỉ khi thiếu; có fallback group/main cần tránh dùng âm thầm cho profile mới.
- `docs/opencode.md:157–158` yêu cầu restart để reload chưa khớp docs V2 hot reload.
- `.gitignore` không bỏ `.opencode/plans`; không thay bằng cleanup tự động.

### 3.3 Thay đổi có sẵn phải giữ

`AGENTS.md`, bảy profile, `docs/leader.md`, `docs/opencode.md`, `scripts/doctor.sh`, `scripts/setup-mcp.sh` đã bẩn trước task. `setup-mcp.sh` không thuộc phạm vi sửa lần này. Chỉ so diff với baseline đã chụp để phân biệt công việc mới. Không checkout/reset/stash/clean; không stage file.

## 4. Thiết kế

### 4.1 Đợt 1 — an toàn và state contract

1. Viết lại profile theo cấu trúc ngắn đồng nhất: vai/khả năng; quyền và phạm vi; task mode; input/handoff; thao tác; cổng; report. Mỗi profile tự đủ các luật tối quan trọng, không dựa vào việc skill lạ luôn tồn tại.
2. Leader không nạp skill/đọc source/shell. Quyền chỉ cho phép công cụ cần thiết; mọi coarse API có khả năng tạo session/release không được mở chỉ để xem trạng thái. Các tác vụ ask/secret/render cần tuân thủ harness, không dùng question để nhận secret hay ép một lựa chọn định hướng thiếu note.
3. Workers deny subagent/question; reviewers edit plan only; testers edit owned test areas only. Shell mặc định deny hoặc ask có giới hạn rõ, inspection cần exact/narrow commands, không allow generic interpreter/eval/curl chỉ vì “chỉ đọc”. Test runner được phép là chạy code dự án tin cậy, không tuyên bố cấm host-write tuyệt đối. Final rules cần qua DIRECTION/PLAN trước coding.
4. CONSULT không ghi plan/source/config; PLAN chỉ ghi plan khi có quyền; CHANGE qua plan/test/audit; RELEASE có approval riêng và snapshot phải còn hợp lệ. Auto-commit convention không vượt lệnh “không commit” của user.
5. Session mới mỗi lượt, giữ ledger theo execution; `idle/completed` không phải session bị xóa. Chờ event child; không poll/sleep hoặc tự bịa stop. Không khởi động cùng group/provider-capacity khi lượt cũ còn chạy; unknown -> BLOCKED/nhờ hủy đúng tool.
6. Contract counters: brief_attempt <=2, direction_attempt <=2, plan_attempt <=2 (gồm lượt đầu), plan_repairs <=2/task, code_iteration <=3 (gồm implement đầu), infra_retry <=1/operation. 413 dùng session mới; mutation timeout phải xác minh kết quả trước retry; không làm mới budget sau đổi plan.
7. PASS khi mọi gate bắt buộc có evidence cho snapshot hiện tại; FAIL khi có lỗi xác minh; BLOCKED thiếu môi trường/bằng chứng; N/A chỉ khi thật sự không áp dụng và có lý do. Không lấy đa số phủ quyết lỗi. Ba tester mặc định cho CHANGE; đổi minimum phải được chốt theo risk trước chạy/approval, không giảm vì bận.
8. Coverage giao theo R/AC, tester không chứng minh UI ngoài quyền; Leader gộp coverage, reviewplan audit đủ toàn task.
9. Partial plan: step_state PENDING/APPLIED/PARTIAL/BLOCKED, plan revision và fingerprint. Minor repairs có bằng chứng trong phạm vi được phép; đổi thiết kế/AC/phạm vi phải quay Review/Leader, không tự hạ AC.
10. Baseline + ownership + index: không gom user staged work; nếu có overlap không rõ -> BLOCKED. Duyệt commit/push tách riêng, kiểm snapshot và staged diff; giữ plan, cleanup là quyền riêng.

### 4.2 Đợt 2 — chất lượng/context/evals

1. Plan STANDARD dùng thiết kế, constraints, contracts, touched units, tests/AC và key snippets; STRICT mới cần exact whole-file/TÌM-THAY. Reviewplan kiểm nguyên khối số occurrence (0/1/>1), không regex nhiều dòng sai; không cấm spread/rest/literal từ yêu cầu.
2. Tester1 functionality/regression; Tester2 adversarial/auth/idempotency/assertions; Tester3 contract/runtime/side effects/E2E. Cô lập môi trường/namespace/port/browser hoặc tách build-tests rồi freeze rồi execute. Không tuyên bố cách ly chỉ vì tên file khác.
3. File naming theo framework, marker owner không thay discovery convention. Test owner được sửa file của mình vòng sau, không source/file người khác.
4. UI chỉ khi ảnh hưởng flow/AC hoặc smoke đã phân công. Browser lease một owner; audit read-only không thay E2E mutation. Test reset/POST chỉ trong namespace test được phép; logs/network kỳ vọng lỗi đối chiếu AC, không auto fail response cố ý giả lập lỗi.
5. Artifacts `/tmp/opencode/<slug>/` hoặc vùng gitignored xác minh; logs redacted, output report ngắn + exit code + đường dẫn. Handoff theo byte budget, không embed ảnh/base64, không chỉ giới hạn số dòng. Evidence ghi plan revision/source fingerprint/test fingerprint/run label.
6. Skills có availability/required flag và allowlist vai; giữ cấm bundle magpie, hai ngoại lệ khi giao đích danh, skill hệ thống bắt buộc theo chỉ dẫn thật; thiếu optional warn, required BLOCKED. Không tự cài skill hay đổi project config.
7. MCP inventory động: kiểm tool đúng phiên, không hứa luôn có 5 MCP; biến mất -> report BLOCKED gate liên quan. Model/group runtime là nguồn thật; chỉ lập hướng dẫn thử diversity sau eval, không tự đổi model/tài khoản/group.
8. Có contract machine-readable cho validator/tests: versioned IDs, bounds, statuses, scope và owner; prompt không cần tool tự đọc source này. Test offline kiểm policy và static consistency; scenario suite phân biệt deterministic fixture vs live agent trial, không gọi fixture check là thành công end-to-end của LLM.
9. Safe update: source validate trước; dry-run mặc định; chỉ apply explicit; check expected hashes toàn batch trước ghi; giữ model override của installed; không override custom body ngoài expected; backup trước ghi, atomic replace từng file; từ chối symlink/path nguy hiểm; no-op không tạo backup; install-missing giữ nguyên file có sẵn; không tác động group/MCP/config. Hoàn tất dưới parent build để không cắt quyền coder giữa lượt.

### 4.3 Phương án bị loại

- Chỉ sửa lời cấm, giữ policy base allow: không xử lý gap tools/shell đã xác nhận.
- Bật tất cả shell/MCP để giữ tiện: phủ nhận mục tiêu phân quyền.
- Thêm plugin orchestration hoặc sandbox/container mới toàn hệ thống: ngoài scope, cần quyền/ops riêng; thay bằng narrow policies + disclosure + scenario evidence.
- Đổi ngay model family hoặc reset group theo docs: không được duyệt tài khoản/model, có thể làm mất routing user đã chỉnh.
- Luôn code đầy đủ trong mọi plan: lặp implementation/context; chỉ giữ dưới STRICT khi có lý do.

## 5. Hợp đồng dữ liệu

`agent-contract.json` dùng JSON chuẩn UTF-8, version số nguyên; đúng 7 role IDs. Không có secrets hay trạng thái live. Ít nhất chứa task modes, outcome vocabulary, counters, role coverage/capabilities và policy invariant tests. Parser frontmatter chỉ hỗ trợ tập con được repo xuất ra; sai cú pháp/duplicate key/rule shape phải fail rõ, không pretend YAML parser tổng quát.

Handoff/report tối thiểu cho mọi lượt:

```json
{
  "task_mode": "CHANGE",
  "project_root": "/absolute/project",
  "slug": "task-slug",
  "plan_path": "/absolute/project/.opencode/plans/task-slug/plan.md",
  "plan_revision": 1,
  "requirements": ["R1: observable result"],
  "assigned_coverage": ["R1/AC1"],
  "snapshot_id": "sha256-of-declared-inputs",
  "permissions_granted": ["source edits in listed files"],
  "release_approved": false,
  "cleanup_approved": false,
  "skill": {"id": "opencode", "required": true},
  "budget": {"code_iteration": 1, "infra_retry": 0},
  "outcome": "BLOCKED",
  "evidence": []
}
```

Đây là schema giao tiếp đề xuất, không bắt từng báo cáo phải in một khối JSON dài. Field thiếu không được suy thành approval. CONSULT không yêu cầu plan_path; path/model/secret không được log tràn.

Sync CLI: mọi lỗi input/conflict/validation exit !=0 và không đụng batch; check/dry-run không ghi; apply có backup path và kết quả từng profile. Chấp nhận expected manifest rõ schema từ baseline (hoặc hash map do dry-run xuất), không chấp nhận hash không liên quan. Target model override được giữ; source mode/capability không bị tùy tiện thay bởi model preservation.

## 6. Các bước thay đổi

### Bước 1 — Chốt policy sau kiểm DIRECTION/PLAN

- Nhận Reviewplan DIRECTION, sửa mục 4 nếu có STEER. Phải chốt hard-vs-soft enforcement, shell và MCP action names.
- Kiểm docs V2 thay vì V1; không sửa JSONC/provider schema.
- Kiểm: plan có R1–R12 và danh sách file đầy đủ, budget và quyền đã được user duyệt.

### Bước 2 — Đợt 1: cập nhật 7 profile và contract

- Sửa Description như báo cáo được user duyệt; keep IDs/mode/model.
- Thêm V2 permissions có phạm vi, task modes, consent, ledger/counters, coverage/statuses, ownership, partial-step rules, safe baseline/release.
- Không áp live ngay khi coder còn chạy.
- Kiểm: parser/validator; header keys hợp lệ; loại mọi câu “cùng phiên”, “session đóng vĩnh viễn”, Nhóm A giả, thiếu tester vẫn PASS, tự xóa plan.

### Bước 3 — Đợt 2: tinh gọn prompt/runbook

- Gộp nguồn chuẩn counter/status/contract, bỏ ví dụ lặp dài; mỗi role tự đủ safety cốt lõi.
- STANDARD/STRICT, skills/capability, UI/locks/logs/evidence snapshot và các nhiệm vụ tester riêng.
- Sửa `docs/leader.md`, vùng liên quan `docs/opencode.md`, `AGENTS.md` đúng scope. Không đụng `scripts/setup-mcp.sh` và nội dung headless của user.
- Kiểm: links trong repo thật, consistency contract với từng role; không claim live routing theo bảng cũ.

### Bước 4 — Validator, regression và scenario fixtures

- Node built-ins; parser strict subset, last-match wildcard evaluator cho offline regression, không dùng làm bằng chứng thay Core runtime.
- Positive và negative tests: bỏ deny, mở source cho reviewer/tester, mở forbidden MCP/skill/shell, duplicate/invalid headers, thiếu gate, contract mismatch, request payload ellipsis hợp lệ.
- Scenario fixtures: CONSULT/no-write, PLAN/no-code, explicit no-commit vs auto convention, staged user work, UI AC owner/fallback, partial plan, missing tester, flaky/infra, 413, provider fallback capacity, snapshot changed after audit, owner test sửa vòng sau.
- Kiểm: `node --test tests/*.test.mjs`; mutant fixture phải bị validator bắt.

### Bước 5 — Safe installer/sync + doctor

- Thêm agents-only updater và test temp config; source validate/expected hash/preserve model/backups/atomic individual write/refuse symlink/no-op.
- Tích hợp setup giữ install-missing an toàn; chỉ thêm doctor check, không reset models/group hay chạy MCP khi chỉ đồng bộ agent.
- Kiểm: dry-run không ghi, conflict bất kỳ profile -> batch không đổi, custom model preserved, unexpected custom body conflict, invalid source rollback-safe, missing target install, symlink rejected, unrelated file unchanged.

### Bước 6 — Test độc lập và audit

- Sau coder xong, đóng băng source mới và tách lệnh/artifacts cho 3 tester. Không sửa source khi tester chạy.
- Tester1 test functional/validator/install; Tester2 negative/property/regressions; Tester3 data contract/runtime load/integration/scope (không cần browser cho thay đổi Markdown/CLI này).
- Reviewplan AUDIT xem diff so baseline, test và mapping R; không yêu cầu pending TÌM tồn tại cho applied steps.
- Còn lỗi -> coder lượt mới, tối đa 3 iterations toàn task; retry infra 1/operation.

### Bước 7 — Áp dụng profile thật và xác nhận API

- Parent build chỉ sau tests/audit; kiểm target còn khớp expected baseline hoặc dừng nếu session khác sửa.
- Chạy sync dry-run rồi apply explicit; backup 7 installed profiles; không restart, không reload/mutate magpie provider/groups.
- Gọi `opencode api get /api/agent` qua CLI; so descriptions/system/permissions/model/mode với expected (envelope data), không print secrets/config đầy đủ.
- Kiểm đủ 7 và không thay unrelated installed files, model overrides preserved. Nếu đang có agent cũ chạy: nói rõ phiên mới dùng profile mới, phiên cũ không đảm bảo đổi model/quyền giữa chừng.
- Báo user plan path, file chính, tests thật, limitations live eval, backup path; không commit/push/dọn plan.

## 7. Xử lý lỗi & trường hợp biên

| Trường hợp | Hành vi |
|---|---|
| Target đã đổi từ baseline | Sync BLOCKED toàn batch trước ghi, không overwrite user work |
| File/dir target là symlink không tin cậy | Từ chối ghi, report path, không unlink |
| Model override khác source | Giữ model override có sẵn, không auto fallback main |
| Header/rule source invalid | Validator exit nonzero, installer không ghi |
| File test owner tồn tại từ vòng trước | Cho sửa khi ownership đã giao, convention đúng framework |
| File source đổi trong lúc test | Evidence invalid/BLOCKED, không kết luận implementation sai chỉ từ hash |
| Một tester/quota/tool mất | Không giảm required gate; retry infra 1, BLOCKED nếu vẫn thiếu |
| Cùng DB/port/cache hoặc file test discovery | Cô lập hoặc tuần tự; không claim parallel isolation |
| UI check là deliberate 5xx path | So expected handling theo AC, không fail chỉ dựa status HTTP |
| Action có tác dụng phụ timeout | Xác minh state trước retry, tránh ghi/commit đôi |
| Skill required không có | BLOCKED phần liên quan; không cài ngầm, optional chỉ warn |
| MCP disconnect giữa lượt | Giữ evidence đã có, đánh dấu gate còn thiếu, không bịa tool |
| Plan có spread/rest `...` | Hợp lệ nếu code đầy đủ; chỉ reject placeholder mơ hồ |
| Plan đang apply dở | Theo step_state và snapshot, không ép preconditions cũ cho applied step |
| Logs chứa secret | Redact trước artifact/report; không đọc auth/key phục vụ test |
| Sync thất bại do quyền/đĩa | Giữ backup và trạng thái từng file; không claim toàn batch atomic nếu OS không cung cấp transaction |

## 8. Test plan

- Unit parser/contract/policy: role IDs/modes/model binding, last rule wins, deny source/test foreign ownership/MCP, allowed inspector/workflow tools tương ứng, skill allowlist và explicit exceptions.
- Negative fixtures/mutation: xóa deny hoặc thêm overbroad allow phải fail; malformed YAML subset phải fail closed; đa occurrence TÌM không được xem là unique.
- Installer temp dirs: dry-run/no-op, install-missing, check drift, apply conflict preflight, backup content, custom model, symlink, unrelated files, failing validation. Không chạy thử trên HOME thật trong unit tests.
- Scenario fixtures kiểm decision expectations + prompt contractual coverage; phân loại đây là deterministic contract tests, không end-to-end LLM benchmark.
- Regression cả suite; `bash -n` scripts touched; `git diff --check` cả file mới/cũ.
- Runtime: GET agents sau sync xác nhận Core parse/merge thực tế; không gọi tools nguy hiểm để prove deny.
- Live 7-agent trial hiện task tự là một smoke integration với các báo cáo thật; không coi như baseline A/B hoặc benchmark diversity.

## 9. Tiêu chí nghiệm thu

| AC | Kiểm tra | Kết quả |
|---|---|---|
| AC1 | `node scripts/check-agents.mjs` | exit 0, đủ 7 valid profiles, contract consistent |
| AC2 | `node --test tests/*.test.mjs` | exit 0; có ca âm/mutation và tests fixture installer không rỗng |
| AC3 | `bash -n scripts/setup-opencode.sh scripts/doctor.sh` | exit 0 |
| AC4 | `git diff --check` | exit 0, không whitespace lỗi mới |
| AC5 | Sync dry-run + fixture tests | không ghi/config, preserve model/unrelated files, conflict fail closed |
| AC6 | Sync apply máy + authenticated API agents | backup có thật; 7 descriptions/system/policies đúng bản mới, model/mode giữ nguyên |
| AC7 | Audit so với baseline và R1–R12 | không revert user work, setup-mcp.sh/index/provider/model/settings không đổi |
| AC8 | Handoff cuối | plan còn giữ, không commit/push, không claim live eval hay sandbox chưa chạy |

## 10. Lệnh kiểm tra

Working directory cho mọi lệnh repo: `/home/caigicungdc98/magpie-cloudshell`.

```bash
node scripts/check-agents.mjs
node --test tests/*.test.mjs
bash -n scripts/setup-opencode.sh scripts/doctor.sh
git diff --check
```

Đây là các entrypoint mới của task, không giả là script manifest cũ. Không có lint/typecheck/build độc lập trong repo; đã kiểm README và listing root/scripts. Các module JavaScript còn được kiểm cú pháp bằng `node --check` nếu test chưa import tới.

Runtime dùng `opencode api get /api/agent` và `/api/skill` read-only; updater flags chốt trong code/docs/tests trước apply. Không chạy bootstrap/finish/setup-groups/setup-mcp vì có side effects ngoài task.

## 11. Rủi ro & rollback

- Permission quá chặt có thể chặn công cụ cần thiết. Test theo vai + API parse trước áp; không hot-update bảy profiles lúc coder/tester/audit của task còn cần quyền cũ. Thiếu tool -> BLOCKED rõ, không auto mở wildcard.
- Broad shell/test execution không thể thành sandbox chỉ bằng permissions. Runbook phải công bố điều này; không tự cài container/sandbox hay khẳng định host read-only.
- Profiles là global, ảnh hưởng phiên mới ở project khác. Giữ model/mode và repo-local skill policy; áp chỉ khi kiểm target hash và backup thành công.
- Rollback là phục hồi **đúng 7 installed files từ backup đã tạo**, chỉ khi target còn là bản do task vừa áp; không git checkout/reset source đang bẩn. Source rollback nếu cần theo delta task so baseline, không chép đè công việc user.
- Cần budget live A/B/diversity riêng nếu muốn đo chất lượng đa model; task này tạo bộ test và tiêu chí, không tiêu quota hàng loạt hoặc thay tài khoản.

## 12. Ngoài phạm vi

- Không thay routing/model/account, không reset group, không auth/login/logout, không sửa Magpie JSON hoặc OpenChamber settings.
- Không sửa `scripts/setup-mcp.sh`/Chrome install, không update CLI/plugin/provider, không restart dịch vụ.
- Không UI redesign, không thêm agent thứ tám, không framework workflow mới, không broad worktree cleanup.
- Không commit/push/deploy, không git add/stash/reset/checkout/clean, không xóa plan hoặc user files.

## 13. Câu hỏi mở

- Chốt cụ thể policy shell/MCP/execute và tích hợp updater sau Reviewplan DIRECTION; là câu hỏi kỹ thuật, không cần user quyết lại hướng đã duyệt. Khi chốt phải bổ sung phụ lục quyết định trước coder.
- Không còn câu hỏi về scope/user approval.

## Phụ lục A — quyết định sau DIRECTION STEER

DIRECTION đã trả `STEER`. User sau đó yêu cầu **không giao cho agent nào**, tự làm. Các điều chỉnh dưới đây thay thế chỗ tương ứng ở mục 4–7 và được dùng khi triển khai:

1. **`ask` không phải cổng trên máy này.** `~/.config/openchamber/settings.json` có `permissionDefaultMode: "auto"` và `permissionAutoAccept` cho nhiều session; rule `ask` bị tự động chấp nhận. Mọi ranh giới cứng dùng `deny`; `ask` chỉ còn là gợi ý thao tác, không được tính là biện pháp an toàn.
2. **Shell:** `review` dùng allowlist đọc hẹp (deny `shell *` rồi allow các lệnh đọc cụ thể). `reviewplan`, `coder`, ba tester cần chạy lệnh test tuỳ project nên dùng deny-list các lệnh phá huỷ/ra ngoài vai; đây là **best-effort**, không phải sandbox. Không deny `execute` cho năm vai này; chỉ Leader deny `execute` vì Leader không cần Code Mode.
3. **MCP:** tên action là `<server>_<tool>` với ký tự không hợp lệ đổi thành `_`, ví dụ `chrome_devtools_navigate_page`, `magpie_sessions_search_sessions`. Sau khi áp dụng phải kiểm sống bằng một phiên rẻ; nếu tên thực tế khác, sửa rule và ghi bằng chứng, không suy đoán.
4. **Session ledger:** hạ xuống ledger trong-lượt + handoff. Leader không có shell nên không kiểm quota/capacity provider xuyên lượt; `magpie-sessions` chỉ là transcript, không phải trạng thái chạy. Không hứa kiểm quota.
5. **Installer:** thêm `--sync` (backup, giữ `model:` cục bộ, atomic write) và `--no-mcp`; không nhúng vào `finish.sh`; test trong `HOME` tạm.
6. **Test:** dùng Python 3 chuẩn + bash, không thêm framework; bốn lớp: lint frontmatter, oracle policy offline, installer trong temp HOME, regression âm. Khi service tắt/không xác minh được → `BLOCKED`, không `PASS`.
7. **Biên đã chốt:** tester chỉ được ghi file test có marker owner theo convention; `external_directory` giữ mặc định vì project root thay đổi, ghi rõ giới hạn; Reviewplan được giữ `chrome-devtools` nhưng prompt giới hạn AUDIT; skill deny đích danh `magpie-skills`/`openchamber-extensions`, giữ `opencode`/`report` và skill project; Coder deny sửa plan và deny `git push --force*`/`git push -f*`, còn commit/push thường vẫn theo prompt + approval vì permission tĩnh không diễn đạt được “chỉ sau khi user duyệt”.
8. **Không chạy live 7-agent trial trong lượt này** vì user yêu cầu không giao cho agent và các group đang bận. Bằng chứng gồm test offline + API parse; live scenario chỉ là kịch bản chưa chạy, không được báo như đã đạt.

## Phụ lục B — bản ghi triển khai (2026-11-20)

Đã sửa trong repo:

- `config/agents/{leader,review,reviewplan,coder,tester,tester2,tester3}.md`:
  Description ngắn; task mode; status PASS/FAIL/BLOCKED/N/A; session idle wording;
  coverage theo vai; ownership test; plan STANDARD/STRICT; partial step state;
  baseline/index/release; skill availability; MCP động; permission V2.
- `config/agent-contract.json`: contract version 1 cho 7 role, counters, outcomes.
- `scripts/check-agents.py`: parser frontmatter + validator rule/text/contract.
- `scripts/sync-agents.py`: check/dry-run/apply/install-missing, backup, giữ model,
  expected manifest, chống symlink, atomic write, chỉ chạm 7 profile.
- `scripts/setup-opencode.sh`: thêm `--sync`, `--no-mcp`; mặc định vẫn install-missing.
- `scripts/doctor.sh`: thêm kiểm contract và drift profile.
- `tests/test_agents.py`: 16 test offline; `tests/fixtures/agent-scenarios.json`:
  11 kịch bản contract cho live eval sau này.
- `AGENTS.md`, `docs/leader.md`, `docs/opencode.md`, `README.md`: đồng bộ mô tả,
  permission, session, skill/MCP, installer sync.

Bằng chứng đã chạy:

```text
python3 scripts/check-agents.py            -> ok: 7 profiles checked
python3 -m unittest discover -s tests ...  -> 16 tests OK
bash -n scripts/setup-opencode.sh scripts/doctor.sh -> ok
python3 -m py_compile ...                  -> ok
git diff --check                           -> ok
```

Đã áp live:

```text
bash scripts/setup-opencode.sh --sync --no-mcp \
  --expected-manifest /tmp/opencode/agents-audit-v2-baseline/installed-manifest.json
-> WROTE 7 profiles; backup 20261120T103234Z (đã xóa sau xác nhận)
python3 scripts/sync-agents.py --check --target ~/.config/opencode/agents
-> ok: 7 profiles match source
opencode api get /api/agent
-> leader primary group/leader perm 21; review perm 41; reviewplan perm 36;
   coder perm 13; tester/tester2 perm 47; tester3 perm 45
-> model/mode giữ nguyên; description mới hiện đúng
```

Chưa làm và lý do:

- **Đã kiểm tên action MCP sống:** probe runtime cho thấy action đúng là
  `chrome-devtools_navigate_page` (giữ dấu gạch ngang), không phải
  `chrome_devtools_navigate_page`. Rule underscore **không chặn**; đã đổi toàn bộ
  sang `chrome-devtools_*`, thêm deny cho Leader, và probe lại thấy tool bị ẩn.
  Không cần deny `execute` cho tester/tester2 vì rule hyphen đã ẩn tool khỏi Code Mode.
- **Chưa chạy live 11 scenario** với LLM: đây là fixture contract, không phải benchmark.
- **Chưa commit/push**: đúng quyền user đã duyệt; plan được giữ lại.
- **Không đổi** group/provider/model/tài khoản, không restart service, không chạy
  `finish.sh`/`setup-groups.sh`/`setup-mcp.sh`.

## Phụ lục C — runtime test 3 ca (2026-11-20)

Đã chạy bằng `opencode run --agent ...` trong temp repo, không giao subagent:

1. **CONSULT không ghi file**
   - `review` đọc `app.txt`, trả bảng nội dung, không tạo plan/thư mục, không sửa file.
   - `git status` sau chạy chỉ có file log test; `app.txt` không đổi.
2. **CHANGE với working tree bẩn**
   - Repo temp có `app.txt` dirty + `user-staged2.txt` staged.
   - Lần BRIEF đầu **FAIL một phần**: `review` bị deny shell vì model gộp
     `cd ... && git status && echo ...`; allowlist chỉ có `git status*` nên `cd`/`echo`
     không khớp. Đã thêm `cd *`, `echo *`, `printf *` vào allowlist review.
   - Chạy lại: `review` BRIEF chạy được `git status`, `git diff`, `git diff --cached`;
     brief ghi đúng HEAD, file dirty, file staged, untracked và `snapshot_id`.
   - `coder` đọc plan, tạo `new.txt` đúng nội dung, giữ nguyên `app.txt` dirty và
     `user-staged2.txt` staged, không stage/commit, báo baseline + `plan_revision`.
3. **`tester3` gọi `chrome-devtools`**
   - Lần đầu **FAIL**: rule `chrome_devtools_*` (underscore) không khớp; `tester3`
     gọi được `chrome-devtools.navigate_page` qua Code Mode.
   - Probe xác định action đúng là `chrome-devtools_navigate_page` (giữ dấu gạch
     ngang). Rule `chrome-devtools_*` ẩn tool khỏi cả direct tool và Code Mode.
   - Sau sửa: `leader`, `review`, `tester`, `tester2` không còn thấy `chrome-devtools`;
     `tester3` vẫn gọi được `navigate_page`; API xác nhận rule hyphen trên 4 profile.
   - Bài học: docs/example dùng underscore có thể sai với MCP server có hyphen; phải
     probe runtime, không suy từ tên server.

Test artifact nằm trong `/tmp/opencode/{consult-test,dirty-test,perm-test-tester3}`;
không nằm trong repo. Đã xóa sau khi tổng hợp kết quả.
