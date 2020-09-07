# cocoapods-nexus
[![Gem Version](https://badge.fury.io/rb/cocoapods-nexus.svg)](https://badge.fury.io/rb/cocoapods-nexus)

让[CocoaPods](https://cocoapods.org/)支持[Nexus](https://www.sonatype.com/nexus)的插件.

## 背景

多数管理podspec都是通过git来维护私有库，而随着项目越来越大，cocoapods安装慢、编译慢也成为了问题。常见的解决方式是提前预编译framework来加速。常见的方案有[cocoapods-binary](https://github.com/leavez/cocoapods-binary)、[Rome](https://github.com/tmspzz/Rome)等工具。

考虑团队现有的环境，感觉都不适合现状，团队以有nexus服务器，考虑是否能复用nexus，因此整理出该插件。通过nexus来管理podspec和预编译framework。

## 安装

```shell
$ gem install cocoapods-nexus
```

## 使用

### 常用命令

#### Add

添加一个nexus的repo，类似**pod repo add**

```shell
$ pod nexus add RepoName NexusHostUrl
# 例如:
# pod nexus add ios_release http://ip:port
```

#### List

显示已有nexus的repo，类似**pod repo list**

```shell
$ pod nexus list
```

#### Push

推送podspec到nexus的repo，类似**pod repo push**。其中artifact为可选参数

```shell
$ pod nexus push path/to/podspec --url=NexusHostUrl --repo=RepoName --artifact=path/to/预编译文件

# 例如:
# pod nexus push ~/demo.podspec --url=http://ip:host --repo=ios_release --artifact=~/demo.zip
```

### Podfile配置

通过如下代码添加nexus的repo
```ruby
plugin 'cocoapods-nexus', :sources => [
  {
    :name => "ios",
    :url => "http://ip:port",
  }
]

# 其中name为repo的name，url为nexus的地址
# 添加以上代码后执行pod install,插件会从nexus查询podspec
```

## 注意事项

### 1.如何鉴权

考虑到nexus会私有部署、通过[~/.netrc](https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html)文件配置权限

```shell
machine nexusip
login nexus_user
password nexus_password
```

### 2.服务器地址

插件关于nexus的相关操作只需要配置ip和host，后续的mount地址默认为nexus，暂时不支持修改。

## 致谢

- [cocoapods-art](https://github.com/jfrog/cocoapods-art)
- [cocoapods-repo-svn](https://github.com/dustywusty/cocoapods-repo-svn)
- [nexus_api](https://github.com/Cisco-AMP/nexus_api)
- 等其他
