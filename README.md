# ❄️ My NixOS + Hyprland Dotfiles

Mi configuración personal de NixOS gestionada con **Flakes** y **Home Manager**.

## 🛠️ Estructura del repositorio
- `flake.nix`: Punto de entrada del sistema.
- `hosts/laptop/`: Configuración específica de mi laptop (Hardware y Home Manager).
- `modules/`: Módulos de Hyprland, Waybar y mi configuración avanzada de Neovim.

## 🚀 Cómo replicar esta configuración
Para aplicar los cambios en esta máquina o una nueva:
```bash
sudo nixos-rebuild switch --flake .#laptop
```
## 🧑‍💻 Personalización
- **Hyprland**: Configuración personalizada para un entorno de trabajo eficiente.
- **Neovim**: Configuración avanzada con plugins para desarrollo.
- **Waybar**: Barra de tareas personalizada con información útil.
- **Home Manager**: Gestión de dotfiles y aplicaciones de usuario.
- **ml4w**: Configuración de mi entorno de desarrollo.

## 3. Cómo crear el repositorio desde la Terminal

No necesitas abrir el navegador para nada. Si tienes instalada la herramienta oficial de GitHub (`gh`), el proceso toma 3 comandos.

Ejecuta esto en tu terminal dentro de `~/system/nixos`:

```bash
# 1. Inicia sesión en GitHub desde la terminal (si no lo has hecho antes)
gh auth login

# 2. Haz tu primer commit con todos tus archivos actuales
git add .
git commit -m "feat: initial nixos flake setup with hyprland and nvim"

# 3. Crea el repositorio directamente en tu cuenta de GitHub y sube el código
# (Lo crearemos PRIVADO por seguridad, puedes cambiarlo a público luego si quieres)
gh repo create nixos-config --private --source=. --remote=origin --push
```
