import os
import platform
import subprocess

def get_linux_distribution():
    try:
        with open('/etc/os-release', 'r') as f:
            for line in f:
                if line.startswith('ID='):
                    return line.split('=')[1].strip().strip('"').lower()
    except FileNotFoundError:
        pass
    
    return None

def install_package(package_name):
    distname = get_linux_distribution()
    
    if distname in ['debian', 'ubuntu']:
        cmd = ['sudo', 'apt', 'install']
    elif distname in ['fedora', 'centos', 'redhat']:
        cmd = ['sudo', 'yum', 'install']
    elif distname == 'arch':
        cmd = ['sudo', 'pacman', '-S']
    else:
        print(f"Unsupported distribution: {distname}. Please install {package_name} manually.")
        return
    
    subprocess.run(cmd + [package_name, '-y'])


def run_command(command):
    result = os.system(command)
    if result != 0:
        print(f"Error occurred while executing: {command}")

# Check the operating system and install necessary packages
if platform.system() == 'Linux':
    install_package('socat')
    run_command("curl https://get.acme.sh | sh")
    run_command("~/.acme.sh/acme.sh --set-default-ca --server letsencrypt")
    run_command("~/.acme.sh/acme.sh --register-account -m kenzo@gmail.com")

    run_command(f"clear")
    domain = input("Please enter your domain: ")
    run_command(f"~/.acme.sh/acme.sh --issue -d {domain} --standalone --force")


    copy_ssl = input("Do you want to copy the SSL files to /root? (y/n): ")

    if copy_ssl.lower() == 'y':
        run_command(f"~/.acme.sh/acme.sh --installcert -d {domain} --key-file /root/private.key --fullchain-file /root/cert.crt --force")
        run_command(f"clear")
        print("")
        print(20 * "###")
        print(f"Full Chain: /root/cert.crt")
        print(f"Private Key: /root/private.key")
        print("")
        print(20 * "###")
        print("Process complete.")

    else:
        run_command(f"clear")
        print(20 * "###")
        print("")
        print(f"Full Chain: /root/.acme.sh/{domain}_ecc/fullchain.cer")
        print(f"Private Key: /root/.acme.sh/{domain}_ecc/{domain}.key")
        print("")
        print(20 * "###")
        print("Process complete.")
else:
    print(f"Unsupported operating system: {platform.system()}. Please run this script on a Linux system.")
    
    
    

