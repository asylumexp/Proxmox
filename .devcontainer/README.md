Proxmox devcontainer — Shell scripting focused

This devcontainer is intentionally lightweight and focused on maintaining and developing the shell scripts in the repository (the `ct/`, `turnkey/`, `vm/`, etc. folders).

What it includes
- Shell tooling: shellcheck, shfmt (for linting/formatting shell scripts)
- Common CLI utilities: git, curl, make, jq, bash completion
- Docker client installed and the Docker socket mounted (so you can run Docker from inside the container if your host allows it)

How to use
1. Open this repository in VS Code.
2. When prompted, "Reopen in Container". Alternatively: Command Palette -> Remote-Containers: Reopen in Container.

Post-create actions
- The container prints a ready message. All tooling is installed at image build time.

Notes
- This container is not Go-focused. The `api/` folder is intentionally not prepared in the container; if you later need to work on Go in-container we can add Go or switch back to a Go base.
- To change tooling or add linters, edit `.devcontainer/Dockerfile` and rebuild.
