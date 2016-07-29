GenreInfo = {};
GenreInfo.parse = function (str) {
    var ok = (/^([a-z]{2})?([?]?)(@{0,3})([+]?)(.*)$/).exec(str);

    if (ok == null) {
        return null;
    } else {
        return {
            yellow_page: ok[1] || "",
            hide_status: ok[2] == '?',
            access_level: ok[3].length,
            no_statistics: ok[4] == '+',
            words: ok[5]
        };
    }
};

GenreInfo.toString = function (info) {
    var at = ['', '@', '@@', '@@@'];

    return info.yellow_page + (info.hide_status ? '?' : '') + at[info.access_level] + (info.no_statistics ? '+' : '') + info.words;
};

// console.log ( GenreInfo.parse("sp?プログラミング") );
// console.log ( GenreInfo.parse("sp?+?!?!?!?!?プログラミング") );
// console.log ( GenreInfo.parse("saaaaプログラミング") );
// console.log ( GenreInfo.parse("#include <stdio.h>") );
