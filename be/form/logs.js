'use strict';

var url = require('url');
var aggregatedLogs = require('../db').aggregatedLogs();
var miscOps = require('../engine/miscOps');
var formOps = require('../engine/formOps');
var domManipulator = require('../engine/domManipulator').dynamicPages.miscPages;

exports.getMinDate = function(informedYear) {

  var date = new Date();

  date.setJSTHours(0);
  date.setJSTMinutes(0);
  date.setJSTSeconds(0);
  date.setJSTDate(1);
  date.setJSTMilliseconds(0);
  date.setJSTMonth(0);

  if (informedYear) {

    var parsedYear = +informedYear;

    if (parsedYear) {
      date.setJSTFullYear(parsedYear);
    }
  }

  return date;

};

exports.process = function(req, res) {

  var parameters = url.parse(req.url, true).query;

  if (parameters.boardUri && /\W/.test(parameters.boardUri)) {
    delete parameters.boardUri;
  }

  var date = exports.getMinDate(parameters.year);
  var json = parameters.json;

  var maxDate = new Date(date);

  maxDate.setJSTFullYear(maxDate.getJSTFullYear() + 1);

  aggregatedLogs.aggregate([ {
    $match : {
      date : {
        $gte : date,
        $lt : maxDate
      },
      boardUri : parameters.boardUri || null
    }
  }, {
    $sort : {
      date : -1
    }
  }, {
    $group : {
      _id : 0,
      dates : {
        $push : '$date'
      }
    }
  } ]).toArray(
      function gotDates(error, results) {

        if (error) {
          formOps.outputError(error, 500, res, req.language, json);
        } else {

          results = results.length ? results[0].dates : [];

          if (json) {
            formOps.outputResponse('ok', results, res, null, null, null, true);
          } else {
            formOps.dynamicPage(res, domManipulator.logs(results, parameters,
                req.language));
          }
        }

      });

};