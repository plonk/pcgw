$(function () {
    var text = $('#genre-input-text')[0];
    var menu = $('#genre-input-menu')[0];
    var hide_status = $('#genre-input-hide-status')[0];
    var no_statistics = $('#genre-input-no-statistics')[0];

    function setValues() {
        var info = GenreInfo.parse(text.value);
        
        menu.value            = info.access_level + "";
        hide_status.checked   = info.hide_status;
        no_statistics.checked = info.no_statistics;
    }

    function setString() {
        var info = GenreInfo.parse(text.value);

        info.access_level  = +menu.value;
        info.hide_status   = hide_status.checked;
        info.no_statistics = no_statistics.checked;

        text.value = GenreInfo.toString(info);
    }

    $('#genre-input-text').on('input', function() {
        setValues();
    });

    $('#genre-input-menu, #genre-input-hide-status, #genre-input-no-statistics').on('change', function() {
        setString();
    });

    setValues();
});
