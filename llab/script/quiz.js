// instance dispatch on type

function getQInstance(type, qdata, location,  i) {
    // based on value of 'type' attribute in the div with class=asessment-data
    if (type == "multiplechoice") {
        return new MC(qdata, location, i);
    }
    return null;
}


//////////////


// puts qdatums into the hidden div, continues processing
$(document).ready(buildQuestions);

/**
 * Process each div with class assessment-data, start xmlhttp calls as necessary.
 */
function buildQuestions() {
    // we don't do english here!  datas!!!
    var qdatas = $("div.assessment-data");
    var num = qdatas.length;

    for (var i = 0; i < num; i++) {
        var qdata = $(qdatas.get(i));
        var location = $("<div>").insertAfter($(qdata));
        if (qdata.attr("src")) {
            var target = qdata.attr("src");
            getRemoteQdata(target, location, i);

        } else {
            buildQuestion(qdata, location, i);
        }
    }

    // now, remove the purely data tags, how about?
    $("div.assessment-data").remove();

}

// use a closure to keep around location and questionNum
function getRemoteQdata(target, location, questionNum) {
    $.ajax({
        url : target,
        type : "GET",
        dataType : "html",
        success : makeGetRemoteQdataCallback(location, questionNum)
    });
}

function makeGetRemoteQdataCallback(location, questionNum) {
    var callback = function(data) {
        buildQuestion(data, location, questionNum);
    };
    return callback;
}



// qdata is a div with the relevant data
// location is a div whose contents will be replaced with the question.
function buildQuestion(qdata, location, questionNum)  {
    qdata = $(qdata).insertBefore(location);
    var type = qdata.attr("type");
    var question = getQInstance(type, qdata, location, questionNum);
    // An unimplemented question type must not abort the whole page: buildQuestions
    // loops over every .assessment-data div, so throwing here would drop every
    // question after this one. (A handful of pages ship type="fillin", which has
    // no implementation.)
    if (!question) {
        llab.handleError(new Error(`Unsupported question type: ${type}`));
        return;
    }
    question.loadContent();
    question.render();
}
