# Lockora 产品介绍页

站点地址为 https://tbtparent.me/lockora/，静态目录为 `/srv/www/lockora`。

产品页使用仓库根目录的 `landing.html`、`landing.css`、`landing.js` 和 `landing-assets/`。部署时将 `landing.html` 命名为 `index.html`，其余资源保持相对目录结构。`web/` 是 Flutter 浏览器应用的入口文件。

Nginx 配置源文件为 `nginx/lockora.conf`，服务器配置路径为 `/etc/nginx/business/tbtparent.me/lockora.conf`。旧的 `/password-manager` 地址跳转到 `/lockora/`。

更新前备份现有静态目录和配置；先准备完整资源，再替换配置，执行 `nginx -t` 通过后重载 Nginx。验证新页面、CSS、JavaScript、图标和旧地址跳转，缺失资源应返回 404。
