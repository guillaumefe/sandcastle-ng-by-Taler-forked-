# sandcastle-ng-by-Taler-forked-
Fork de https://git.taler.net/sandcastle-ng.git/tree/

# Installation and Configuration of GNU Taler via Sandcastle

## 1. Environment Preparation

### Opening a Terminal
- Open the system's application menu.
- Search for the "Terminal" application.
- Click on the terminal application icon to open it.

### Installing Necessary Tools
In the terminal, install Podman and Vim (a CLI text editor if you don't already have one):
```bash
apt install podman vim
```

## 2. Workspace Configuration

### Creating a Workspace
Navigate to the user's personal space and create a new folder for the project:
```bash
cd ~
mkdir GNU_Taler_Sandcastle
cd GNU_Taler_Sandcastle
```

### Downloading and Preparing the Project
Download the Git repository of the Sandcastle project and enter the directory:
```bash
git clone https://git.taler.net/sandcastle-ng.git
cd sandcastle-ng
```

## 3. Component Verification and Configuration

### Verifying Component Versions
Access the configuration directory and list the `.tag` files:
```bash
cd buildconfig
ls -l *tag
```
Use the `find` command to display the content of each `.tag` file (ensure each file has a version as content, changing theses is beyond the scope of this README):
```bash
find . -type f -name "*.tag" -exec sh -c 'echo "==== {} ===="; cat {}' \;
./print-latest-versions
./print-component-versions
```
Return to the project root:
```bash
cd ..
```

## 4. Project Construction

### Building the Container Image
Launch the construction of the container image and wait for the compilation to finish:
```bash
./sandcastle-build
podman images
```

## 5. Deployment Configuration

### Modifying Configuration Scripts
Open and modify `scripts/demo/setup-sandcastle.sh` to define the currency used:
```bash
vim scripts/demo/setup-sandcastle.sh
```
Also adjust `sandcastle-run` to configure the ports:
```bash
vim sandcastle-run
```

## 6. Deployment Launch and Management

### Executing the Deployment
Launch the container in the background and check its operation:
```bash
./sandcastle-run -d
podman ps
podman port taler-sandcastle
```

## 7. Testing and Maintenance

### Deployment Testing
Enter the container to access an internal shell and test the interfaces:
```bash
./sandcastle-enter
```

### Inspection and Stop of the Deployment
Inspect the data volume and stop the container:
```bash
podman volume inspect talerdata
podman stop taler-sandcastle
```
To restart, use:
```bash
podman stop taler-sandcastle
podman start taler-sandcastle
podman restart taler-sandcastle
```

