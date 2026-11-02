# Preparar el VPS (fase 1)

Guía paso a paso para dejar el VPS listo y seguro. Los comandos de tu PC son
para **PowerShell** en Windows. Los del VPS se escriben dentro de la sesión SSH.

Puertos que quedan abiertos:

| Uso | Puertos |
|---|---|
| SSH | 22 (con límite de intentos) |
| Web (MyAAC) | 80, 443 |
| Producción: login, juego, estado | 7171, 7172, 7173 |
| Pruebas: login, juego, estado | 7271, 7272, 7273 |

## 1. Contratar el VPS

En OVHcloud, VPS-2 (o equivalente), **Ubuntu 24.04**, centro de datos en Europa.
Cuando te pida una clave SSH, pega tu clave pública (la línea que empieza por
`ssh-ed25519`). Si no te la pide, no pasa nada: OVH te mandará por correo un
usuario (`ubuntu`) y una contraseña.

Apunta la **IP** del VPS. En esta guía sale como `IP_DEL_VPS`.

## 2. Primera conexión

En PowerShell:

```powershell
ssh ubuntu@IP_DEL_VPS
```

La primera vez pregunta si te fías del servidor: escribe `yes`. Si te pide
contraseña, usa la del correo de OVH.

## 3. Ejecutar el script

Ya dentro del VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/nocthold-serv/nocthold/develop/infra/vps/bootstrap.sh -o bootstrap.sh
sudo bash bootstrap.sh
```

Tarda unos minutos. Al final muestra un resumen con "Listo".

## 4. Comprobar que entras (sin cerrar la ventana anterior)

**No cierres la primera ventana.** Abre otra PowerShell y prueba:

```powershell
ssh nocthold@IP_DEL_VPS
```

Debe entrar sin pedir contraseña. Dentro, comprueba:

```bash
sudo whoami          # debe decir: root
docker run --rm hello-world
```

Si funciona, ya puedes cerrar las dos ventanas. A partir de ahora se entra
siempre con `ssh nocthold@IP_DEL_VPS`. El usuario `ubuntu` y `root` ya no
pueden entrar por SSH.

Si **no** entra, no cierres la primera ventana y avisa: desde ella se puede
arreglar.

## 5. Atajo opcional en tu PC

Para escribir solo `ssh nocthold`:

```powershell
notepad $HOME\.ssh\config
```

Pega esto, cambia la IP y guarda:

```
Host nocthold
    HostName IP_DEL_VPS
    User nocthold
```

## Añadir la clave del compañero (o de alguien nuevo)

1. Tu compañero genera su clave en su PC (si no tiene) y muestra la pública:

   ```powershell
   ssh-keygen -t ed25519 -C "su-nombre"
   Get-Content $HOME\.ssh\id_ed25519.pub
   ```

2. Esa línea se pega en [`authorized_keys`](authorized_keys) (en la línea
   marcada como PENDIENTE) y se sube a `develop`.
3. En el VPS:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/nocthold-serv/nocthold/develop/infra/vps/bootstrap.sh -o bootstrap.sh
   sudo bash bootstrap.sh
   ```

   El script se puede repetir sin problema: solo añade lo que falte.

## Avisos

- **Docker se salta ufw** en los puertos que publica un contenedor. En los
  `docker-compose` nunca publiques el puerto de MariaDB (3306); la base de
  datos solo debe ser accesible desde la red interna de Docker.
- El VPS se reinicia solo a las 05:30 si una actualización de seguridad lo pide.
- Para ver quién ha sido bloqueado por fail2ban: `sudo fail2ban-client status sshd`.
