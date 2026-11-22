# FreePi5 — plugin riêng cho tài khoản FreePi thứ năm

`FreePi5` là một provider **riêng** của magpie, dùng để đăng nhập một tài khoản
FreePi **khác** với các tài khoản còn lại. Nó không phải bản sao của `freepi`
hay các FreePi khác: mã nguồn plugin nằm trong repo private
<https://github.com/Duc-Nguyen-739/FreePiLogin5>, có icon riêng, mô tả tiếng Việt,
và lưu trạng thái trong thư mục `~/.freepi5`.

Repo đó chứa hai thứ:

| Thư mục | Nội dung |
|---|---|
| `index.mjs`, `lib/`, `package.json` | plugin magpie `magpie-freepi5-auth` → provider `freepi5` |
| `upstream/FreePi2API/` | bản sao đầy đủ mã nguồn [FreePi2API](https://github.com/ErfanBagheri404/FreePi2API) (proxy Python stdlib, **không phải** plugin magpie) |

## Cài trên máy khác

Repo là **private**. Máy mới cần đọc được repo bằng `gh` (hoặc clone sẵn), rồi cài
từ thư mục local:

```sh
gh auth login                      # tài khoản có quyền đọc Duc-Nguyen-739/FreePiLogin5
gh repo clone Duc-Nguyen-739/FreePiLogin5 ~/.local/src/FreePiLogin5
magpie plugin add ~/.local/src/FreePiLogin5
```

Nếu đã có bản clone:

```sh
git -C ~/.local/src/FreePiLogin5 pull --ff-only
magpie plugin add ~/.local/src/FreePiLogin5
```

`magpie plugin add` với cùng đường dẫn sẽ nạp lại mã plugin tại chỗ; không cần
gỡ plugin, không mất token đăng nhập.

Kiểm tra:

```sh
magpie plugin list | grep -A1 FreePi5
# /home/<bạn>/.local/src/FreePiLogin5  on
#   freepi5 (FreePi5, 28 models)  not signed in · magpie plugin login freepi5
```

`magpie providers` **chưa** hiện FreePi5 trước khi đăng nhập — xem mục
“Vì sao `magpie providers` không thấy FreePi5” bên dưới.

## Đăng nhập

Trên máy có trình duyệt:

```sh
magpie plugin login freepi5
```

Trên Cloud Shell / máy headless, dùng web UI:

1. `openmagpie`
2. Settings → Providers → Add provider → **From plugins** → **FreePi5**
3. Chọn **Đăng nhập bằng mã thiết bị GitHub**, mở link GitHub và nhập mã.

Token nằm trong `~/.config/magpie/plugin-auth.json` ở khoá `freepi5`; không đụng
token của `freepi` / `freepi2` / `freepi3` / `freepi4`.

## Dùng

```sh
magpie provider test freepi5 deepseek-v4.1-flash
magpie provider models freepi5
magpie group set main models+=freepi5/deepseek-v4.1-flash
```

Model hiện ra dưới dạng `freepi5/<model-id>`, ví dụ
`freepi5/deepseek-v4.1-flash`.

## Lưu trữ tách biệt

| Thứ | Nơi lưu |
|---|---|
| Token | `~/.config/magpie/plugin-auth.json`, khoá `freepi5` |
| Session id thiết bị | `~/.freepi5/session-id` — UUID ngẫu nhiên, file `0600`, thư mục `0700` |
| Đổi chỗ lưu | `FREEPI5_HOME=/đường/dẫn/khác` |

`~/.freepi5` khác hoàn toàn `~/.freepi2`, `~/.freepi3` và `~/.freepi4`, và không
dùng chung hằng số `magpie-freepi` của plugin `freepi`. Mỗi máy cài sinh một UUID
riêng, nên hai máy không gửi cùng `x-session-id`.

magpie không cho plugin tự chọn file credential: token luôn nằm trong
`plugin-auth.json` theo provider id. Vì vậy “hai kho khác nhau” ở đây là **hai
khoá credential độc lập** cộng với **hai thư mục trạng thái độc lập**, không phải
hai file token rời.

## Vì sao `magpie providers` không thấy FreePi5

`magpie providers` chỉ liệt kê provider đã có cấu hình hoặc đã đăng nhập. Một
provider mới từ plugin, chưa có auth, chỉ hiện ở:

- `magpie plugin list` (dòng `freepi5 (FreePi5, …)`), và
- web UI `/api/providers`, mục `plugins`.

Sau khi đăng nhập thành công, `freepi5` xuất hiện trong `magpie providers` và
`magpie models`. Gateway đang chạy đọc `providers.json` động, nên route
`freepi5/*` dùng được ngay, không phải restart `magpie serve`.

## Vướng mắc đã gặp và cách xử lý

### 1. `magpie plugin add github:…` trả 404 với repo private

Đây là vướng mắc lớn nhất. Các cách sau **đều không chạy** với repo private:

```sh
magpie plugin add github:Duc-Nguyen-739/FreePiLogin5
magpie plugin add git+https://github.com/Duc-Nguyen-739/FreePiLogin5.git
GITHUB_TOKEN="$(gh auth token)" magpie plugin add github:Duc-Nguyen-739/FreePiLogin5
```

Lý do: magpie gọi bun 1.4.4 đi kèm (`~/.cache/magpie/bun/1.4.4/magpie-bun`), và
bun đổi mọi spec GitHub thành một lần tải:

```
GET https://api.github.com/repos/Duc-Nguyen-739/FreePiLogin5/tarball/
```

Lần tải đó **không gửi header `Authorization`**. Với repo public, GitHub trả
tarball; với repo private, GitHub trả `404` (cố tình không tiết lộ repo có tồn
tại hay không). Đã thử `GITHUB_TOKEN` và `GITHUB_ACCESS_TOKEN`; bun vẫn không
gửi token. `curl` cùng URL **có** token trả `302`, nên token không phải vấn đề —
vấn đề là bun không dùng token cho endpoint tarball.

Cách chạy được:

```sh
gh repo clone Duc-Nguyen-739/FreePiLogin5 ~/.local/src/FreePiLogin5
magpie plugin add ~/.local/src/FreePiLogin5
```

`gh` dùng credential helper của chính nó, nên chỉ cần `gh auth login` một lần.
`scripts/plugins.sh` của repo shell-cloud làm đúng chuỗi này và chỉ cảnh báo
(nếu thiếu quyền) thay vì làm hỏng cả bộ cài.

### 2. `git+ssh` chạy được nhưng không tiện cho máy mới

Đã thử tạo deploy key riêng, thêm vào repo, chạy `ssh-agent` rồi:

```sh
magpie plugin add git+ssh://git@github.com/Duc-Nguyen-739/FreePiLogin5.git
```

Cách này cài được, nhưng mỗi máy phải có khoá SSH riêng và phải cấu hình
`~/.ssh/config` hoặc agent. Vì vậy nó chỉ là phương án dự phòng, không phải cách
chính. Nếu dùng, đừng commit khoá; thêm public key vào repo bằng
`gh repo deploy-key add`.

### 3. Plugin đã cài nhưng chưa thấy provider

Ban đầu `magpie plugin list` thấy `freepi5`, nhưng `magpie providers` và
`magpie models` không thấy. Nguyên nhân: provider chưa có auth. Sau khi đăng
nhập, mọi thứ hiện ra. Không cần restart gateway.

### 4. Ad gate `403 {"code":"ads_required"}`

free-pi trả 403 cho completion nếu tài khoản chưa báo banner impression gần đây.
`magpie-freepi-auth` đã làm việc này; `magpie-free-pi` thì không, nên phải vá
bằng `scripts/patch-free-pi-ads.mjs`. FreePi5 **đã tích hợp sẵn** luồng:

```
GET /ads/next?slot=banner  →  POST /ads/impression
```

Không cần patch. Nếu completion trả 403 `ads_required`, kiểm tra log plugin và
chạy `magpie provider test freepi5 deepseek-v4.1-flash`.

### 5. Client version 426

Upstream có thể nâng `min` client version và trả `426 your free-pi-cli is below
the required minimum`. FreePi5 đọc `/client-version` và tự canh
`x-client-version` theo `latest`, không ghim số như bản `free-pi` cũ. Nếu vẫn
426, chạy `magpie plugin add ~/.local/src/FreePiLogin5` để nạp bản mới.

### 6. Bảy tài khoản trên cùng một upstream

`freepi`, `freepi2`, `freepi3`, `freepi4`, `freepi5`, `freepi6` và `freepi7` cùng gọi `api.freepi.ai`, nhưng là bảy tài khoản
khác nhau:

| Provider | Tài khoản trên máy này |
|---|---|
| `freepi` | `Duc-Nguyen-739` (Reviewer Plan) |
| `freepi2` | `huenguyen-code` |
| `freepi3` | `hoangphat-coder` |
| `freepi4` | `phucth2002-spec` |
| `freepi5` | `ngocson-coder` |
| `freepi6` | `haiquan-tbs` |
| `freepi7` | `thuylinh-coder` (Pi7 - Tester 2) |

FreePi5 tách `x-session-id`, token, thư mục trạng thái và budget. **Không tách
được IP**: nếu cả bảy đi ra cùng một địa chỉ mạng, upstream vẫn thấy chúng sau
cùng một IP, và mỗi JWT đều định danh tài khoản. Plugin không thể bảo đảm server
không phát hiện. Nếu cần khác IP, đặt proxy riêng cho FreePi5:

```sh
magpie plugin options ~/.local/src/FreePiLogin5 '{"proxy":"http://proxy-host:8080"}'
magpie plugin options ~/.local/src/FreePiLogin5 off   # bỏ proxy
```

Đây là biện pháp giảm khả năng bị gộp, không phải bảo đảm tuyệt đối.

### 7. Icon và mô tả

- Icon FreePi5 là SVG riêng: nền tím → hồng cánh sen → hồng đậm, tia chớp trắng,
  huy hiệu số **5** màu hồng. Không dùng icon của freepi.ai.
- `magpie.name` = `FreePi5`; `magpie.summary.vi` và `description` viết tiếng Việt.
- Nhãn phương thức đăng nhập chỉ có `vi`; không có bản tiếng Anh để tránh UI
  tiếng Anh hiển thị mô tả khác.
- Tên model vẫn là id gốc của upstream (`deepseek-v4.1-flash`, …) — đó là id
  kỹ thuật, không phải mô tả.

### 8. Token và bảo mật

- Token không nằm trong repo. `plugin-auth.json` và `~/.freepi5/session-id` chỉ
  nằm trên máy.
- `.gitignore` của repo chặn `node_modules/`, `auth.json`, `__pycache__/`, log.
- Không chạy `magpie` bằng `sudo`; không sửa tay `plugin-auth.json`.
- Repo private: chỉ tài khoản được mời mới đọc được. Khi chia sẻ máy, đăng xuất
  `gh` nếu không muốn người khác clone được.

## Kiểm tra nhanh

```sh
magpie plugin list | grep -A1 FreePi5
magpie providers | grep FreePi5
magpie models | grep '^freepi5/'
magpie provider test freepi5 deepseek-v4.1-flash
bash scripts/doctor.sh | grep FreePi5
```

Kỳ vọng:

```
freepi5 (FreePi5, 28 models)  signed in as ngocson-coder
✓ FreePi5: session id riêng (~/.freepi5, quyền 600)
✓ FreePi5 đã đăng nhập
```

## Cập nhật và gỡ

```sh
git -C ~/.local/src/FreePiLogin5 pull --ff-only
magpie plugin add ~/.local/src/FreePiLogin5
```

Gỡ plugin:

```sh
magpie plugin logout freepi5     # tuỳ chọn: xoá token khỏi plugin-auth.json
magpie plugin rm ~/.local/src/FreePiLogin5
```

## Giới hạn

Đây là plugin cộng đồng **không chính thức**, dịch ngược từ `free-pi-cli`.
Upstream đổi giao thức là plugin có thể hỏng. Nó không được FreePi bảo trợ, và
việc dùng nhiều tài khoản có thể vi phạm điều khoản của FreePi; tự cân nhắc rủi
ro bị khoá tài khoản. Mã nguồn FreePi2API trong `upstream/` giữ nguyên bản quyền
của tác giả gốc.
