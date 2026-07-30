# Security Policy / 安全政策

## Reporting / 回報

Do not disclose suspected vulnerabilities, credentials, tokens, cookies, or private configuration in a public issue. Use GitHub's private security advisory flow when available, or contact the repository owner through a private channel.

請勿在公開 Issue 揭露疑似漏洞、憑證、Token、Cookie 或私人設定。若可用，請使用 GitHub Private Security Advisory；否則請透過私下管道聯絡倉庫擁有者。

## If a secret is exposed / 若秘密外洩

1. Rotate or revoke the affected credential immediately.
2. Preserve evidence without reposting the secret.
3. Remove the secret from reachable history with `git filter-repo` after rotation.
4. Force-push only after reviewing the rewritten history and coordinating with collaborators.
5. Consider GitHub Support and downstream forks/caches; rewriting history does not erase copies already fetched by others.

若秘密外洩，第一優先是輪替或撤銷憑證；不要只刪除檔案或 commit。清理 Git 歷史前先完成輪替，並保留不含秘密值的事件紀錄。

## Scope / 範圍

This policy covers the public repository and its validation workflow. It does not authorize publishing private settings or secrets from any local machine.
