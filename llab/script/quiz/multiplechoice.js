// TODO: Save Selectors for button states and buttons
// TODO: Bind click events to google analytics
// TODO: Namespace everything
// TODO: Cache selections of elements
// TODO: Delay writing to DOM until everything is fully rendered
// TODO: Return messages for incorrect answers
// TODO: Randomize the correct messages (need to randomly pick from an array)
// TODO: Remove the alert() call for bad answer selections

/* Represents a multiple choice question. */

function MC(data, location, questionNumber) {
    this.myClass = "MultipleChoice";


    // questionNumber is the index of the question
    this.num = questionNumber;

    this.content = {};
    this.properties = {};
    this.correctResponse = [];
    this.choices = [];
    this.attempts = [];
    this.states = [];

    this.interaction = data;
    //this.responseDec = $($(".responseDeclaration")[this.num]);
    var rii = this.interaction.attr("responseIdentifier");
    this.responseDec = $('.responseDeclaration[identifier="' + rii + '"]');


    // save this MC dom element
    this.multipleChoice = $(location);

    // make a copy of the template
    var template = this.getTemplate();
    this.multipleChoice = $(template).insertAfter(location);

    //boolean to prevent shuffling after each answer submit
    this.previouslyRendered = false;
}


MC.prototype.loadContent = function() {
    var choices = this.choices;
    var i;
    this.interaction.find('.choice').each(function() {
        var elem = $(this);
        var choice = {
            identifier: elem.attr('identifier'),
            text: elem.find('.text').html(),
            feedback: elem.find('.feedback').html()
        };
        choices.push(choice);
    });

    // get user interaction information
    this.content.prompt = this.interaction.find('.prompt').html();
    this.content.additonal_info = this.interaction.find('.additional-info').html();
    this.properties.shuffle = this.interaction.attr('shuffle') == "true";
    this.properties.maxChoices = this.interaction.attr('maxchoices');

    // get the list of correct responses
    var corrResponses = this.responseDec.find('.correctResponse');

    for (i = 0; i !== corrResponses.length; i++) {
        this.correctResponse.push($(corrResponses[i]).attr('identifier'));
    }

};

//gets and returns a choice object given the choice's identifier
MC.prototype.getChoiceByIdentifier = function(identifier) {
    var i = 0;
    for (; i < this.choices.length; i++) {
        if (this.removeSpace(this.choices[i].identifier) == identifier) {
            return this.choices[i];
        }
    }
    return null;
};

llab.numToOrdinal = (number) => {
    if (Math.floor(number / 10) == 1) {
        return `${number}th`;
    } else if (number % 10 == 1) {
        return `${number}st`;
    } else if (number % 10 == 2) {
        return `${number}nd`;
    } else if (number % 10 == 3) {
        return `${number}rd`;
    } else {
        return `${number}th`;
    }
}

MC.prototype.displayNumberAttempts = function(attempts) {
    // if (attempts.length < 1) { return; }
    let count = attempts.length + 1, t = llab.t;
    this.multipleChoice.find('.numberAttemptsDiv').html(t(
        'attemptMessage',
        { number: count, ordinal: llab.numToOrdinal(count) }
    ));
};

MC.prototype.tryAgain = function(e) {
    if (this.multipleChoice.find(".tryAgainButton").hasClass("disabled")) {
        return;
    }
    this.render();
};


/**
 * Render the MC
 * Nate: plan is to have the mc-single-template.body in the html currently, and pull
 * pieces from the data model (that the author makes) into the template
 */
MC.prototype.render = function() {
    let t = llab.translate,
        type = 'radio',
        choiceHTML, choice_id, optId;

    if (!this.previouslyRendered) {
        /* set the question type title */
        this.multipleChoice.find('.questionType').html(t('selfCheckTitle'));
        /* Some questions (mostly summary pages) have a .additional-info div
         * that we want to display as part of the question title. */
        if (this.content.additonal_info) {
            this.multipleChoice.find('.questionType').append(this.content.additonal_info);
        }
    }

    /* render the prompt */
    this.multipleChoice.find('.promptDiv').html(this.content.prompt);

    /* remove buttons */

    var radiobuttondiv = this.multipleChoice.find('.radiobuttondiv')[0];
    while (radiobuttondiv.hasChildNodes()) {
        radiobuttondiv.removeChild(radiobuttondiv.firstChild);
    }

    /*
     * if shuffle is enabled, shuffle the choices when they enter the step
     * but not each time after they submit an answer
     */
    if (this.properties.shuffle && !this.previouslyRendered) {
        this.choices.shuffle();
    }

    if (this.properties.maxChoices != 1) {
        type = 'checkbox';
    }

    // TODO: Bootstrap 5: revisit form CSS classes
    for (let i = 0; i < this.choices.length; i++) {
        optId = this.choices[i].identifier;
        choice_id = `q-${this.num}-${this.removeSpace(optId)}`;
        choiceHTML = `
        <div class="option-row">
            <div class="${type}">
                <label id="choicetext-${choice_id}" for="${choice_id}">
                    <input type="${type}" id="${choice_id}" value="${this.removeSpace(optId)}" />
                    ${this.choices[i].text}
                </label>
            </div>
            <div class="option-feedback" id="feedback_${choice_id}" name="feedback"></div>
        </div>`;

        this.multipleChoice.find('.radiobuttondiv').append(choiceHTML);

        $(`#${choice_id}`).bind('click', { myQuestion: this }, function(args) {
            args.data.myQuestion.enableCheckAnswerButton('true');
        });
        if (this.selectedInSavedState(optId)) {
            $(`#${choice_id}`).attr('checked', true);
        }

        this.multipleChoice.find(".checkAnswerButton").bind('click', {
            myQuestion: this
        }, function(args) {
            args.data.myQuestion.checkAnswer();
        });

        this.multipleChoice.find(".tryAgainButton").bind('click', {
            myQuestion: this
        }, function(args) {
            args.data.myQuestion.tryAgain();
        });
    }

    this.multipleChoice.find('.tryAgainButton').addClass('disabled').attr('disabled', true);
    this.enableCheckAnswerButton('true');
    this.clearFeedbackDiv();

    console.log(this.correctResponse);
    if (this.correctResponse.length < 1) {
        // if there is no correct answer to this question (ie, when they're filling out a form),
        // change button to say "save answer" and "edit answer" instead of "check answer" and "try again"
        // and don't show the number of attempts.
        this.multipleChoice.find(".checkAnswerButton").innerHTML = t("Save Answer");
        this.multipleChoice.find(".tryAgainButton").innerHTML = t("Edit Answer");
    } else {
        this.displayNumberAttempts(this.attempts);
    };

    if (this.states.length > 0) {
        //the student previously answered the question correctly
        var latestState = this.states[this.states.length - 1];
        //display the message that they correctly answered the question
        var resultMessage = this.getResultMessage(latestState.isCorrect);
        this.multipleChoice.find('.resultMessageDiv').html(resultMessage);
        if (latestState.isCorrect) {
            this.multipleChoice.find('.tryAgainButton').addClass('disabled').attr('disabled', true);
        }
    }

    // flag so that the we do not shuffle again during this visit
    this.previouslyRendered = true;
    this.interaction.remove();
    //this.node.view.eventManager.fire('contentRenderComplete', this.node.id, this.node);
};

/**
 * Determine if challenge question is enabled
 */
MC.prototype.isChallengeEnabled = () => false;

/**
 * Determine if scoring is enabled
 */
MC.prototype.isChallengeScoringEnabled = function() {
    var result = false;

    if (this.properties.attempts != null) {
        var scores = this.properties.attempts.scores;
        result = challengeScoringEnabled(scores);
    }

    return result;
};

/**
 * Given a choiceId, checks the latest state and if the choiceId
 * is part of the state, returns true, returns false otherwise.
 *
 * @param choiceId
 * @return boolean
 */
MC.prototype.selectedInSavedState = function(choiceId) {
    var b, latestState;
    if (this.states && this.states.length > 0) {
        latestState = this.states[this.states.length - 1];
        for (b = 0; b < latestState.length; b++) {
            if (latestState.choices[b] == choiceId) {
                return true;
            }
        }
    }

    return false;
};

/**
 * Returns true if the choice with the given id is correct, false otherwise.
 */
MC.prototype.isCorrect = function(id) {
    var h;
    /* if no correct answers specified by author, then always return true */
    if (this.correctResponse.length == 0) {
        return true;
    };

    /* otherwise, return true if the given id is specified as a correct response */
    for (h = 0; h < this.correctResponse.length; h++) {
        if (this.correctResponse[h] == id) {
            return true;
        }
    }
    return false;
};

/**
 * Checks Answer and updates display with correctness and feedback
 * Disables "Check Answer" button and enables "Try Again" button
 */
MC.prototype.checkAnswer = function() {
    if (this.multipleChoice.find('.checkAnswerButton').hasClass('disabled')) {
        return;
    }

    this.multipleChoice.find('.resultMessageDiv').html('');

    this.attempts.push(null);

    var inputbuttons = this.multipleChoice.find('.radiobuttondiv')[0].getElementsByTagName('input');
    var mcState = {};
    var isCorrect = true;
    var i, checked, choiceIdentifier, choice, fullId;

    this.enableRadioButtons(false);
    this.multipleChoice.find('.checkAnswerButton').addClass('disabled').attr('disabled', true);
    this.multipleChoice.find('.tryAgainButton').removeClass('disabled').attr('disabled', false);
    for (i = 0; i < inputbuttons.length; i++) {
        checked = inputbuttons[i].checked;
        choiceIdentifier = inputbuttons[i].getAttribute('value');
        fullId = inputbuttons[i].getAttribute('id')
        // identifier of the choice that was selected
        // use the identifier to get the correctness and feedback
        choice = this.getChoiceByIdentifier(choiceIdentifier);
        if (checked) {
            if (choice) {
                this.multipleChoice.find('#feedback_' + fullId).html(choice.feedback).css('display', 'inline-block');
                var choiceTextDiv = this.multipleChoice.find("#choicetext-" + fullId);
                if (this.isCorrect(choice.identifier)) {
                    choiceTextDiv.attr("class", "correct");
                } else {
                    choiceTextDiv.attr("class", "incorrect");
                    isCorrect = false;
                }
                mcState.identifier = choice.identifier;
                mcState.text = choice.text;
            } else {
                alert('error retrieving choice by choiceIdentifier');
            }
        } else {
            if (this.isCorrect(choice.identifier)) {
                isCorrect = false;
            }
        }
    }

    mcState.isCorrect = isCorrect;

    var outerdiv = this.multipleChoice.find('.panel-heading').parent();
    outerdiv.removeClass('panel-primary');
    outerdiv.removeClass('panel-success');
    outerdiv.removeClass('panel-danger');
    if (isCorrect) {
        outerdiv.addClass('panel-success');
        this.multipleChoice.find('.resultMessageDiv').html(this.getResultMessage(isCorrect));
        this.multipleChoice.find('.checkAnswerButton').addClass('disabled').attr('disabled', true);
    } else {
        outerdiv.addClass('panel-danger');
    }

    // Update Google Analytics
    if (typeof ga === 'function') {
        ga('send', 'event', {
            eventCategory: 'Quiz',
            eventAction: 'checkAnswer',
            eventLabel: this.interaction.attr('identifier'),
            eventValue: isCorrect ? 1 : 0,
            nonInteraction: true // don't count this as an interaction
        });
    }

    // push the state object into this mc object's own copy of states
    this.states.push(mcState);
    return false;
};

/**
 * Returns true iff this.maxChoices is less than two or
 * the number of checkboxes equals this.maxChoices. Returns
 * false otherwise.
 */
MC.prototype.enforceMaxChoices = function(inputs) {
    var x, maxChoices;
    var maxChoices = parseInt(this.properties.maxChoices);
    if (maxChoices > 1) {
        var countChecked = 0;
        for (x = 0; x < inputs.length; x++) {
            if (inputs[x].checked) {
                countChecked += 1;
            }
        }

        if (countChecked > maxChoices) {
            //this.node.view.notificationManager.notify('You have selected too many. Please select only ' + maxChoices + ' choices.',3);
            alert('You have selected too many. Please select only ' + maxChoices + ' choices.');
            return false;
        } else if (countChecked < maxChoices) {
            //this.node.view.notificationManager.notify('You have not selected enough. Please select ' + maxChoices + ' choices.',3);
            alert('You have not selected enough. Please select ' + maxChoices + ' choices.');
            return false;
        }
    }
    return true;
};

/**
 * Given whether this attempt is correct, adds any needed linkTo and
 * constraints and returns a message string.
 *
 * @param boolean - isCorrect
 * @param boolean - noFormat, return plain text
 * @return string - html response
 */
MC.prototype.getResultMessage = function(isCorrect) {
    let t = llab.translate;

    /* if this attempt is correct, then we only need to return a msg */
    if (isCorrect) {
        return t("successMessage");
    }
    return '';
};

/** FIXME -- reusable
 * Returns a string of the given string with all spaces removed.
 */
MC.prototype.removeSpace = function(text) {
    return text.replace(/ /g, '');
};

/**
 * enable checkAnswerButton
 * OR
 * disable checkAnswerButton
 */
MC.prototype.enableCheckAnswerButton = function(doEnable) {
    if (doEnable == 'true') {
        this.multipleChoice.find('.checkAnswerButton').removeClass('disabled').attr('disabled', false);
    } else {
        this.multipleChoice.find('.tryAgainButton').addClass('disabled').attr('disabled', true);
    }
};

/**
 * Enables radiobuttons so that user can click on them
 */
MC.prototype.enableRadioButtons = function(doEnable) {
    var i;
    var radiobuttons = this.multipleChoice.find('input[type="radio"], input[type="checkbox"]');
    for (i = 0; i < radiobuttons.length; i++) {
        if (doEnable == 'true') {
            radiobuttons[i].removeAttribute('disabled');
        } else {
            radiobuttons[i].setAttribute('disabled', 'true');
        }
    }
};


/**
 * Clears HTML inside feedbackdiv
 */
MC.prototype.clearFeedbackDiv = function() {
    var feedbackdiv = this.multipleChoice.find('.feedbackdiv');
    feedbackdiv.innerHTML = "";

    var feedback = this.multipleChoice.find('[name="feedback"]');
    for (let z = 0; z < feedback.length; z++) {
        feedback[z].innerHTML = "";
        feedback[z].style.display = 'none';
    }
};

MC.prototype.postRender = function() {};

MC.prototype.getTemplate = function() {
    let t = llab.translate;
    return `
<div class='panel panel-primary MultipleChoice Question'>
    <div class='panel-heading questionType'>Multiple Choice</div>
    <div class='panel-body currentQuestionBox'>
        <div class='leftColumn'>
            <div class='promptDiv'></div>
            <form class='radiobuttondiv'></form>
            <div class='feedbackdiv'></div>
        </div>
    </div>
    <div class='clearBoth'></div>
    <div class='interactionBox'>
        <div class='statusMessages'>
            <div class='numberAttemptsDiv'></div>
            <div class='scoreDiv'></div>
            <div class='resultMessageDiv'></div>
        </div>
        <div class='buttonDiv'>
            <table class='buttonTable' role="presentation"><tbody>
                <tr role="presentation">
                    <td><div class='buttonDiv'>
                        <button class='checkAnswerButton btn btn-primary'>${t("Check Answer")}</button>
                    </div></td>
                    <td><div class='buttonDiv'>
                        <button class='tryAgainButton btn btn-primary'>${t("Try Again")}</button>
                    </div></td>
                </tr>
            <tbody></table>
        </div>
    </div>
</div>`;
};


/**
 * If prototype 'shuffle' for array is not found, create it
 */
if (!Array.shuffle) {
    Array.prototype.shuffle = function() {
        var rnd, tmp, i;
        for (i = this.length; i; rnd = parseInt(Math.random() * i), tmp = this[--i], this[i] = this[rnd], this[rnd] = tmp) {}
    };
}

llab.loaded['multiplechoice'] = true;
