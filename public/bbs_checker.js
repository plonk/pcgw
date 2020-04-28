$(function () {
    function boardUrl(r) {
        return r.board_url;
    }

    function threadUrl(r) {
        if (r.type !== 'thread') {
            throw new Error("boardUrl: not a thread response");
        }
        return r.thread_url;
    }

    function latestThreadButton(board_url) {
        return "<button type=\"button\" class=\"btn btn-sm btn-secondary\" onclick=\"changeToLatestThread(&quot;" +
            board_url +
            "&quot;)\" title=\"コンタクトURLをこの板でまだ埋まっていない、もっとも最近立てられたスレッドに変更します。\">新スレに移動</button>";
    }

    window.changeToLatestThread = function (board_url) {
        var request_url = "/bbs/latest-thread?" + $.param({ board_url: board_url })
        $.getJSON(request_url, function (data) {
            updateEntry(data);
        }).fail(function () {
            alert("changeToLatestThread: 不明なエラー。");
        });
    }

    function updateEntry(r) {
        if (r.status === "error") {
            alert(r.error_message);
        } else if (r.status === 'ok') {
            if (confirm("コンタクトURL欄をスレッド「" + r.thread_title + "」に変更します。")) {
                $('#bbs-checker-input').val(r.thread_url);
                callback();
            }
        }
    }

    function buildMessage(r) {
        if (r.status == 'error') {
            return "エラー: " + r.error_message;
        } else if (r.status == 'ok') {
            if (r.type == 'board') {
                return "「" + "<a href=\"" + boardUrl(r) + "\">" + r.title + "</a>」掲示板トップ " + latestThreadButton(boardUrl(r));
            } else if (r.type == 'thread') {
                var msg = "掲示板「" + "<a href=\"" + boardUrl(r) + "\">" + r.title + "</a>」のスレ「" + "<a href=\"" + threadUrl(r) + "\">" + r.thread_title + "</a> (";
                if (r.last == r.max) {
                    msg += '<b class="text-danger">';
                    msg += r.last;
                    msg += '</b>';
                } else {
                    msg += r.last;
                }
                msg +=")」";
                return msg + " " + latestThreadButton(boardUrl(r));
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
        if (text != "") {
            var request_url = "/bbs/info?" + $.param({ url: text })
            $.getJSON(request_url, function (data) {
                updateIndicator(data);
            });
        } else {
            clearIndicator();
        }
    }
    callback();
    input.on('change', callback);
    input.on('input', function(){
        $('#bbs-checker-indicator').text("");
        $('#bbs-checker-indicator').removeClass("text-danger");
        $('#bbs-checker-indicator').removeClass("text-success");
    });
});
