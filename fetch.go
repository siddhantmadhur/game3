package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"runtime"
)

func main() {
	// sokol_odin / sokol libs

	fmt.Printf("> Fetching sokol-odin...\n")

	submodule := exec.Command("git", "submodule", "update", "--init")
	err := submodule.Run()
	if err != nil {
		log.Fatal("[ERROR] Could not download sokol-odin!")
	}

	fmt.Printf("> Downloaded sokol-odin!\n")

	fmt.Printf("> Compiling sokol-odin...\n")

	workDir, _ := os.Getwd()

	if runtime.GOOS == "linux" {
		clibs := exec.Command("bash", "build_clibs_linux.sh")
		clibs.Dir = workDir + "/sokol-odin/sokol/"
		err = clibs.Run()
		if err != nil {
			log.Fatalf("[ERROR] Could not download sokol-odin: %s\n", err.Error())
		}
	} else {
		log.Fatal("[ERROR] Operating system or architecture not yet supported by this script")
	}

	fmt.Printf("> Compiled sokol-odin!\n")

	// sokol_shdc
	fmt.Printf("> Fetching sokol-shdc...\n")

	out, err := os.Create("sokol-shdc")
	if err != nil {
		log.Fatalf("[ERROR] Could not create file for sokol-shdc: %s\n", err.Error())
	}

	if runtime.GOOS == "linux" && runtime.GOARCH == "amd64" {
		resp, err := http.Get("https://github.com/floooh/sokol-tools-bin/raw/refs/heads/master/bin/linux/sokol-shdc")
		if err != nil {
			log.Fatal("[ERROR] Could not download sokol-shdc")
		}
		defer resp.Body.Close()

		_, err = io.Copy(out, resp.Body)
		if err != nil {
			log.Fatal("[ERROR] Could not download sokol-shdc")
		}

		err = exec.Command("chmod", "+x", "sokol-shdc").Run()
		if err != nil {
			log.Fatalf("[ERROR] Could not create file for sokol-shdc: %s\n", err.Error())
		}

	} else {
		log.Fatal("[ERROR] Operating system or architecture not yet supported by this script")
	}

	out.Close()

	fmt.Printf("> Downloaded sokol-shdc...\n")
	fmt.Printf("> Compiling shaders...\n")

	entries, err := os.ReadDir("src")
	if err != nil {
		log.Fatal("[ERROR] Could not download sokol-shdc")
	}

	for _, entry := range entries {
		reg, _ := regexp.Compile("[0-9a-z].glsl$")
		isGlsl := reg.MatchString(entry.Name())

		if isGlsl {
			name := entry.Name()[:len(entry.Name())-5]

			fmt.Printf("	> Compiling %s...\n", name)
			shader := exec.Command(workDir+"/sokol-shdc", "-i", "src/"+entry.Name(), "-o", "src/"+name+".shader.odin", "-f", "sokol_odin", "--slang", "glsl430:metal_macos:hlsl5")
			err = shader.Run()
			if err != nil {
				log.Fatalf("[ERROR] Could not compile shader: %s\n", err.Error())
			}
		}
	}
}
