package incus

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"lxdapi/internal/core"
	"lxdapi/pkg/logger"
	"os/exec"
	"strings"
	"time"
)

type Client struct {
	socket  string
	timeout time.Duration
}

func NewClient() *Client {
	cfg := core.GlobalConfig.Virtualization
	return &Client{
		socket:  cfg.Socket,
		timeout: time.Duration(cfg.Timeout) * time.Second,
	}
}

func Binary() string {
	if core.GlobalConfig != nil && core.GlobalConfig.Virtualization.Binary != "" {
		return core.GlobalConfig.Virtualization.Binary
	}
	return "incus"
}

func CommandContext(ctx context.Context, args ...string) *exec.Cmd {
	return exec.CommandContext(ctx, Binary(), args...)
}

func (c *Client) exec(ctx context.Context, args ...string) (string, error) {
	cmd := CommandContext(ctx, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	
	logger.Info("执行虚拟化命令: %s %s", Binary(), strings.Join(args, " "))
	
	err := cmd.Run()
	if err != nil {
		errMsg := stderr.String()
		if errMsg == "" {
			errMsg = err.Error()
		}
		logger.Error("LXC命令执行失败: %s", errMsg)
		return "", fmt.Errorf("%s", errMsg)
	}
	
	return stdout.String(), nil
}

func (c *Client) execJSON(ctx context.Context, result interface{}, args ...string) error {
	output, err := c.exec(ctx, append(args, "--format=json")...)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(output), result)
}
