package com.fpswatcher.app.shizuku;

interface IPrivilegedService {
    String execute(String command);
    void destroy() = 16777114;
}
