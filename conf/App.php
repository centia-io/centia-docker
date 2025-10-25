<?php

namespace app\conf;

class App
{
    static $param = [
        "apiV4" => [
            "rateLimitMode" => "sliding",
            "rateLimitWindowSeconds" => 10, // only used if mode is sliding
            "rateLimitPerMinute" => 120,
        ],
        "host" => "https://api.centia.io",
        "insertCost" => true,
        "memoryLimit" => "1024M",
        "SqlApiSettings" => [
            "statement_timeout" => 20000
        ],
        "sessionHandler" => [
            "type" => "redis",
            "host" => "redis:6379", // without tcp:
            "db" => 1,
        ],
        "appCache" => [
            "type" => "redis",
            "host" => "redis:6379", // without tcp:
            "ttl" => 3600,
            "db" => 0,
        ],
        //Server path where GeoCLoud2 is installed.
        "path" => "/app/",
        // When creating new databases use this db as template
        "databaseTemplate" => "template_geocloud",
        // Master password for admin. MD5 hashed.
        "masterPw" => "8ace28d206750aa2dcee00a3312e7345",
        // Default encoding when uploading data files. If not set it defaults to UTF8
        "encoding" => "UTF8",
        // Trust these IPs
        "AccessControlAllowOrigin" => [
            "*"
        ],
        "github" => [
            // Fill with your GitHub OAuth app credentials
            "clientId" => "Ov23liH0qZetfaZfGQuk",
            "clientSecret" => "cec3c3b7b05a18c314b3e15825d5b31c75d36aa9",
        ],
    ];

    function __construct()
    {
        // This is the autoload function and include path setting. No need to fiddle with this.
        spl_autoload_register(function ($className) {
            $ds = DIRECTORY_SEPARATOR;
            $dir = App::$param['path'];
            $className = strtr($className, '\\', $ds);
            $file = "{$dir}{$className}.php";
            if (is_readable($file)) {
                require_once $file;
            }
        });
        set_include_path(get_include_path() . PATH_SEPARATOR . App::$param['path'] . PATH_SEPARATOR . App::$param['path'] . "app" . PATH_SEPARATOR . App::$param['path'] . "app/libs/PEAR/");
    }
}
