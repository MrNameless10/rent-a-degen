#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"

static size_t cur, peak;

static void *alloc(void *ud, void *p, size_t o, size_t n)
{
    (void)ud;
    if (!p) o = 0;
    if (!n) {
        cur -= o;
        free(p);
        return NULL;
    }
    void *q = realloc(p, n);
    if (q) {
        cur = cur - o + n;
        if (cur > peak) peak = cur;
    }
    return q;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: heap <name> <file.lua>...\n");
        return 2;
    }
    lua_State *L = lua_newstate(alloc, NULL, 0);
    lua_gc(L, LUA_GCCOLLECT);
    size_t base = cur, top = 0, bytecode = 0;
    peak = cur;
    for (int i = 2; i < argc; i++) {
        if (luaL_loadfile(L, argv[i])) {
            fprintf(stderr, "%s\n", lua_tostring(L, -1));
            return 1;
        }
        FILE *f = fopen(argv[i], "rb");
        fseek(f, 0, SEEK_END);
        bytecode += (size_t)ftell(f);
        fclose(f);
        lua_gc(L, LUA_GCCOLLECT);
    }
    top = peak - base;
    printf("%-10s peak %6zu  live %6zu  source %6zu\n", argv[1], top, cur - base, bytecode);
    lua_close(L);
    return 0;
}
