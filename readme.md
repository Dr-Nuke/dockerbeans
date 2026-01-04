# dockerbeans 

`dockerbeans` is a small, self-contained Docker setup to **securely mirror a private Beancount ledger repository** and **serve it via Fava on the local network**.

It is designed to run unattended (e.g. on a Raspberry Pi), pulling updates nightly from GitHub using a **read-only deploy key**, unlocking the repo with **git-crypt**, and exposing the ledger via **Fava (Beancount v3)**.

---

## Quick start (TL;DR)

> Use this if you already know what you�re doing and just want it running again.

1. **Prerequisites**
   - Docker + Docker Compose available
   - Beancount ledger repo on GitHub. This Application expexts it to a private repo

2. **Prepare secrets**
   - all secrets are provided as examples. replace the example files with your secreds in /secrets. create .env fro .env.example and replace the configs within
 
4. **Build & run cleanly**
   ```
   docker compose down -v && docker compose build --no-cache && docker compose up -d

6. **Open Fava**
    ```
    http://<host>:5000
## Step-by-step guide
1. **Create a deploy key (read-only)**

        ssh-keygen -t ed25519 -f dockerbeans-deploy-key -C "dockerbeans deploy key"
2. **Add dockerbeans-deploy-key.pub to the Git repo as deployment key, read only**
3. **if git-crypt is used, export git-crypt key from inside your ledger repo:**

        git-crypt export-key gitcrypt.key
4. **Prepare secrets directory**
            
        secrets/
        +-- dockerbeans-deploy-key
        +-- gitcrypt.key (only of git-crypt is used)
        +-- known_hosts
        +-- smtp.env
        +-- known_hosts

    Example for known_hosts:

        ssh-keyscan github.com > secrets/known_hosts

5. **Adjust .env**
    - if you want email notification on failed deployments, switch the flag to true
    - if you want to use git-crypt, switch the flag to true

6. **Build and start**

        docker compose down -v
        docker compose build --no-cache
        docker compose up -d

6. **Debugging & inspection**

    Enter the sync container:

        docker exec -it ledger-sync bash

    Manually run a sync:

        /app/sync_once.sh

    Inspect logs:

        docker exec -it ledger-sync tail -n 100 /data/logs/sync.log

## Known issues & lessons learned

1. **GIT_SSH_COMMAND must be applied correctly**

    - Must be exported or set inline
    - Must be one single line
    - No ~ expansion
    - No line breaks inside options

2. **docker compose down does NOT reset volumes**

    Old logs and repos may persist unless you use:

        docker compose down -v

5. **Deploy keys are NOT user identities**

    - They are repo-scoped
    - Repo owner SSH keys are irrelevant
    - ssh -T git@github.com greeting might be misleading
    - git ls-remote is the real test