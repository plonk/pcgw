$(function () {
    function isValidBbsUrl(str) {
        var THREAD_URL = /^http:\/\/jbbs\.shitaraba\.net\/bbs\/read\.cgi\/(\w+)\/(\d+)\/(\d+)(?:|\/.*)$/;
        var BOARD_URL = /^http:\/\/jbbs\.shitaraba\.net\/(\w+)\/(\d+)\/?$/;
        if (str.match(THREAD_URL) || str.match(BOARD_URL))
            return true;
        else
            return false;
    }

    function buildMessage(response) {
        if (response.status == 'error') {
            return "エラー: " + response.error_message;
        } else if (response.status == 'ok') {
            if (response.type == 'board') {
                return "「" + response.title + "」掲示板トップ";
            } else if (response.type == 'thread') {
                var msg = "掲示板「" + response.title + "」のスレ「" + response.thread_title + " (";
                if (response.last == response.max) {
                    msg += '<b class="text-danger">';
                    msg += response.last;
                    msg += '</b>';
                } else {
                    msg += response.last;
                }
                msg +=")」";
                return msg;
            } else {
                return "???";
            }
        }
    }

    function updateIndicator(response) {
        $('#bbs-checker-indicator').html(buildMessage(response));
        if (response.status == 'ok') {
            $('#bbs-checker-indicator').addClass("text-success");
            $('#bbs-checker-indicator').removeClass("text-danger");
        } else {
            $('#bbs-checker-indicator').addClass("text-danger");
            $('#bbs-checker-indicator').removeClass("text-success");
        }
    }

    function clearIndicator() {
        $('#bbs-checker-indicator').html('');
    }

    var input = $('#bbs-checker-input');
    function callback() {
        var text = input[0].value;
        if (isValidBbsUrl(text)) {
            var request_url = "/bbs/info?" + $.param({ url: text })
            $.getJSON(request_url, function (data) {
                updateIndicator(data);
            });
        } else {
            clearIndicator();
        }
    }
    callback();
    input.on('input', callback);
});
