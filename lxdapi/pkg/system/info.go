package system

import (
	"os/exec"
	"lxdapi/internal/incus"
	"runtime"
	"strings"
	"os"
)

type SystemInfo struct {
	Name         string `json:"name"`
	Version      string `json:"version"`
	Description  string `json:"description"`
	Docs         string `json:"docs"`
	OS           string `json:"os"`
	Arch         string `json:"arch"`
	IncusVersion string `json:"virtualization_version,omitempty"`
	Distribution string `json:"distribution,omitempty"`
	Kernel       string `json:"kernel,omitempty"`
}

func GetSystemInfo() *SystemInfo {
	info := &SystemInfo{
		Name:        "lxdapi",
		Version:     "v2.1.3",
		Description: "Incus容器管理后端API服务",
		Docs:        "/swagger/index.html",
		OS:          runtime.GOOS,
		Arch:        runtime.GOARCH,
	}
	
	if incusVersion := getIncusVersion(); incusVersion != "" {
		info.IncusVersion = incusVersion
	}
	
	if kernel := getKernelVersion(); kernel != "" {
		info.Kernel = kernel
	}
	
	if distro := getDistribution(); distro != "" {
		info.Distribution = distro
	}
	
	return info
}

func getIncusVersion() string {
	cmd := exec.Command(incus.Binary(), "version")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getKernelVersion() string {
	cmd := exec.Command("uname", "-r")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getDistribution() string {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return ""
	}
	
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			name := strings.TrimPrefix(line, "PRETTY_NAME=")
			name = strings.Trim(name, "\"")
			return name
		}
	}
	
	return ""
}
