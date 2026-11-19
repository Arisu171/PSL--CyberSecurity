<?php
/**
 * MySQL Backward Compatibility Layer for PHP 7.x and PHP 8.x
 * Allows legacy mysql_* functions to work transparently using modern mysqli.
 */

if (!function_exists('mysql_connect')) {
    global $__legacy_mysql_conn;
    $__legacy_mysql_conn = null;

    function mysql_connect($host = 'localhost', $username = 'root', $password = '123456') {
        global $__legacy_mysql_conn;
        // Handle socket or localhost
        $clean_host = ($host === 'localhost') ? '127.0.0.1' : $host;
        $__legacy_mysql_conn = @mysqli_connect($clean_host, $username, $password);
        return $__legacy_mysql_conn;
    }

    function mysql_select_db($db_name, $link_identifier = null) {
        global $__legacy_mysql_conn;
        $conn = $link_identifier ?: $__legacy_mysql_conn;
        if (!$conn) return false;
        return mysqli_select_db($conn, $db_name);
    }

    function mysql_query($query, $link_identifier = null) {
        global $__legacy_mysql_conn;
        $conn = $link_identifier ?: $__legacy_mysql_conn;
        if (!$conn) return false;
        return mysqli_query($conn, $query);
    }

    function mysql_fetch_row($result) {
        if (!$result || !($result instanceof mysqli_result)) return false;
        return mysqli_fetch_row($result);
    }

    function mysql_num_rows($result) {
        if (!$result || !($result instanceof mysqli_result)) return 0;
        return mysqli_num_rows($result);
    }

    function mysql_error($link_identifier = null) {
        global $__legacy_mysql_conn;
        $conn = $link_identifier ?: $__legacy_mysql_conn;
        if (!$conn) return "Database connection failed";
        return mysqli_error($conn);
    }
}
