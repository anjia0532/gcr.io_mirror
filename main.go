package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/google/go-github/v47/github"
	"golang.org/x/oauth2"
	"gopkg.in/alecthomas/kingpin.v2"
	"gopkg.in/yaml.v3"
	"io"
	"io/ioutil"
	"os"
	"regexp"
	"strings"
	"text/template"
)

func main() {
	ctx := context.Background()

	var (
		ghToken           = kingpin.Flag("github.token", "Github token.").Short('t').String()
		ghUser            = kingpin.Flag("github.user", "Github Owner.").Short('u').String()
		ghRepo            = kingpin.Flag("github.repo", "Github Repo.").Short('p').String()
		registry          = kingpin.Flag("docker.registry", "Docker Registry.").Short('r').Default("").String()
		registryNamespace = kingpin.Flag("docker.namespace", "Docker Registry Namespace.").Short('n').String()
		registryUserName  = kingpin.Flag("docker.user", "Docker Registry User.").Short('a').String()
		registryPassword  = kingpin.Flag("docker.secret", "Docker Registry Password.").Short('s').String()
		runId             = kingpin.Flag("github.run_id", "Github Run Id.").Short('i').String()
	)
	kingpin.HelpFlag.Short('h')
	kingpin.Parse()

	config := &Config{
		GhToken:           *ghToken,
		GhUser:            *ghUser,
		Repo:              *ghRepo,
		Registry:          *registry,
		RegistryNamespace: *registryNamespace,
		RegistryUserName:  *registryUserName,
		RegistryPassword:  *registryPassword,
		RunId:             *runId,
		Rules: map[string]string{
			"^gcr.io":          "",
			"^docker.io":       "docker",
			"^k8s.gcr.io":      "google-containers",
			"^registry.k8s.io": "google-containers",
			"^quay.io":         "quay",
			"^ghcr.io":         "ghcr",
		},
	}

	rulesFile, err := ioutil.ReadFile("rules.yaml")
	if err == nil {
		rules := make(map[string]string)
		err2 := yaml.Unmarshal(rulesFile, &rules)
		if err2 == nil {
			config.Rules = rules
		}
	}

	ts := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: config.GhToken},
	)
	tc := oauth2.NewClient(ctx, ts)

	cli := github.NewClient(tc)

	issues, err := getIssues(cli, ctx, config)
	if err != nil {
		fmt.Println("查询 Issues 报错,", err.Error())
		os.Exit(-1)
	}
	if len(issues) == 0 {
		fmt.Println("暂无需要搬运的镜像")
		os.Exit(0)
	}

	// 可以用协程，但是懒得写
	issue := issues[0]

	fmt.Println("添加 构建进展 Comment")
	commentIssues(issue, cli, ctx, "[构建进展](https://github.com/"+config.GhUser+"/"+config.Repo+"/actions/runs/"+config.RunId+")")
	err, originImageName, targetImageName := mirrorByIssues(issue, config)
	if err != nil {
		commentErr := commentIssues(issue, cli, ctx, err.Error())
		if commentErr != nil {
			fmt.Println("提交 comment 报错", commentErr)
		}
	}

	result := struct {
		Success         bool
		Registry        string
		RegistryUser    string
		OriginImageName string
		TargetImageName string
		GhUser          string
		Repo            string
		RunId           string
	}{
		Success:         err == nil,
		Registry:        config.Registry,
		RegistryUser:    config.RegistryUserName,
		OriginImageName: originImageName,
		TargetImageName: targetImageName,
		GhUser:          *ghUser,
		Repo:            *ghRepo,
		RunId:           *runId,
	}

	var buf bytes.Buffer
	tmpl, err := template.New("result").Parse(resultTpl)
	err = tmpl.Execute(&buf, &result)

	fmt.Println("添加 转换结果 Comment")
	res := buf.String()

	commentIssues(issue, cli, ctx, strings.ReplaceAll(res, "^", "`"))

	fmt.Println("添加 转换结果 Label")
	issuesAddLabels(issue, cli, ctx, result.Success)

	fmt.Println("关闭 Issues")
	issuesClose(issue, cli, ctx)
}

var resultTpl = `
{{ if .Success }}
**转换完成**
^^^bash
{{ if .Registry }}
docker login -u{{ .RegistryUser }} {{ .Registry }}
{{ end }}
#原镜像
{{ .OriginImageName }}

#转换后镜像
{{ .TargetImageName }}


#下载并重命名镜像
docker pull {{ .TargetImageName }}

docker tag  {{ .TargetImageName }} {{ .OriginImageName }}

docker images | grep $(echo {{ .OriginImageName }} |awk -F':' '{print $1}')

^^^
{{ else }}
**转换失败**
详见 [构建任务](https://github.com/{{ .GhUser }}/{{ .Repo }}/actions/runs/{{ .RunId }})
{{ end }}
`

func issuesClose(issues *github.Issue, cli *github.Client, ctx context.Context) {
	names := strings.Split(*issues.RepositoryURL, "/")
	state := "closed"
	cli.Issues.Edit(ctx, names[len(names)-2], names[len(names)-1], issues.GetNumber(), &github.IssueRequest{
		State: &state,
	})
}
func issuesAddLabels(issues *github.Issue, cli *github.Client, ctx context.Context, success bool) {
	names := strings.Split(*issues.RepositoryURL, "/")

	label := "success"
	if !success {
		label = "failed"
	}
	cli.Issues.AddLabelsToIssue(ctx, names[len(names)-2], names[len(names)-1], issues.GetNumber(), []string{label})
}
func commentIssues(issues *github.Issue, cli *github.Client, ctx context.Context, comment string) error {
	names := strings.Split(*issues.RepositoryURL, "/")
	_, _, err := cli.Issues.CreateComment(ctx, names[len(names)-2], names[len(names)-1], issues.GetNumber(), &github.IssueComment{
		Body: &comment,
	})
	return err
}

func mirrorByIssues(issues *github.Issue, config *Config) (err error, originImageName string, targetImageName string) {
	// 去掉前缀 [PORTER] 整体去除前后空格
	originImageName = strings.TrimSpace(strings.Replace(*issues.Title, "[PORTER]", "", 1))
	targetImageName = originImageName

	if strings.ContainsAny(originImageName, "@") {
		return errors.New("@" + *issues.GetUser().Login + " 不支持同步带摘要信息的镜像"), originImageName, targetImageName
	}

	registrys := []string{}
	for k, v := range config.Rules {
		targetImageName = regexp.MustCompile(k).ReplaceAllString(targetImageName, v)
		registrys = append(registrys, k)
	}

	if strings.EqualFold(targetImageName, originImageName) {
		return errors.New("@" + *issues.GetUser().Login + " 暂不支持同步" + originImageName + ",目前仅支持同步 `" + strings.Join(registrys, " ,") + "`镜像"), originImageName, targetImageName
	}

	targetImageName = strings.ReplaceAll(targetImageName, "/", ".")

	if len(config.RegistryNamespace) > 0 {
		targetImageName = config.RegistryNamespace + "/" + targetImageName
	}
	if len(config.Registry) > 0 {
		targetImageName = config.Registry + "/" + targetImageName
	}
	fmt.Println("source:", originImageName, " , target:", targetImageName)

	//execCmd("docker", "login", config.Registry, "-u", config.RegistryUserName, "-p", config.RegistryPassword)
	cli, ctx, err := dockerLogin(config)
	if err != nil {
		return errors.New("@" + config.GhUser + " ,docker login 报错 `" + err.Error() + "`"), originImageName, targetImageName
	}

	//execCmd("docker", "pull", originImageName)
	err = dockerPull(originImageName, cli, ctx)

	if err != nil {
		return errors.New("@" + *issues.GetUser().Login + " ,docker pull 报错 `" + err.Error() + "`"), originImageName, targetImageName
	}

	//execCmd("docker", "tag", originImageName, targetImageName)
	err = dockerTag(originImageName, targetImageName, cli, ctx)
	if err != nil {
		return errors.New("@" + *issues.GetUser().Login + " ,docker tag 报错 `" + err.Error() + "`"), originImageName, targetImageName
	}

	//execCmd("docker", "push", targetImageName)
	err = dockerPush(targetImageName, cli, ctx, config)
	if err != nil {
		return errors.New("@" + *issues.GetUser().Login + " ,docker push 报错 `" + err.Error() + "`"), originImageName, targetImageName
	}

	return nil, originImageName, targetImageName
}

func dockerLogin(config *Config) (*client.Client, context.Context, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, nil, err
	}
	fmt.Println("docker login, server: ", config.Registry, " user: ", config.RegistryUserName, ", password: ***")
	authConfig := types.AuthConfig{
		Username:      config.RegistryUserName,
		Password:      config.RegistryPassword,
		ServerAddress: config.Registry,
	}
	ctx := context.Background()
	_, err = cli.RegistryLogin(ctx, authConfig)
	if err != nil {
		return nil, nil, err
	}
	return cli, ctx, nil
}
func dockerPull(originImageName string, cli *client.Client, ctx context.Context) error {
	fmt.Println("docker pull ", originImageName)
	pullOut, err := cli.ImagePull(ctx, originImageName, types.ImagePullOptions{})
	if err != nil {
		return err
	}
	defer pullOut.Close()
	io.Copy(os.Stdout, pullOut)
	return nil
}
func dockerTag(originImageName string, targetImageName string, cli *client.Client, ctx context.Context) error {
	fmt.Println("docker tag ", originImageName, " ", targetImageName)
	err := cli.ImageTag(ctx, originImageName, targetImageName)
	return err
}
func dockerPush(targetImageName string, cli *client.Client, ctx context.Context, config *Config) error {
	fmt.Println("docker push ", targetImageName)
	authConfig := types.AuthConfig{
		Username: config.RegistryUserName,
		Password: config.RegistryPassword,
	}
	if len(config.Registry) > 0 {
		authConfig.ServerAddress = config.Registry
	}
	encodedJSON, err := json.Marshal(authConfig)
	if err != nil {
		return err
	}
	authStr := base64.URLEncoding.EncodeToString(encodedJSON)

	pushOut, err := cli.ImagePush(ctx, targetImageName, types.ImagePushOptions{
		RegistryAuth: authStr,
	})
	if err != nil {
		return err
	}
	defer pushOut.Close()
	io.Copy(os.Stdout, pushOut)
	return nil
}

type Config struct {
	GhToken           string            `yaml:"gh_token"`
	GhUser            string            `yaml:"gh_user"`
	Repo              string            `yaml:"repo"`
	Registry          string            `yaml:"registry"`
	RegistryNamespace string            `yaml:"registry_namespace"`
	RegistryUserName  string            `yaml:"registry_user_name"`
	RegistryPassword  string            `yaml:"registry_password"`
	Rules             map[string]string `yaml:"rules"`
	RunId             string            `yaml:"run_id"`
}

func getIssues(cli *github.Client, ctx context.Context, config *Config) ([]*github.Issue, error) {
	issues, _, err := cli.Issues.ListByRepo(ctx, config.GhUser, config.Repo, &github.IssueListByRepoOptions{
		//State: "closed",
		State:     "open",
		Labels:    []string{"porter"},
		Sort:      "created",
		Direction: "desc",
		// 防止被滥用，每次最多只能拉20条，虽然可以递归，但是没必要。
		//ListOptions: github.ListOptions{Page: 1, PerPage: 20},
		// 考虑了下，每次还是只允许转一个吧
		ListOptions: github.ListOptions{Page: 1, PerPage: 1},
	})
	return issues, err
}
