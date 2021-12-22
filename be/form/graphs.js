'use strict';

var url = require('url');
var miscOps = require('../engine/miscOps');
var formOps = require('../engine/formOps');
var domManipulator = require('../engine/domManipulator').dynamicPages.miscPages;
var files = require('../db').files();

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

  var date = exports.getMinDate(parameters.year);

  var maxDate = new Date(date);

  maxDate.setJSTFullYear(maxDate.getJSTFullYear() + 1);

  var json = parameters.json;

  files.aggregate([ {
    $match : {
      'metadata.date' : {
        $gte : date,
        $lt : maxDate
      },
      'metadata.type' : 'graph'
    }
  }, {
    $sort : {
      'metadata.date' : -1
    }
  }, {
    $group : {
      _id : 0,
      dates : {
        $push : '$metadata.date'
      }
    }
  } ]).toArray(function gotDates(error, results) {

    if (error) {
      formOps.outputError(error, 500, res, req.language, json);
    } else {

      var dates = results.length ? results[0].dates : [];

      if (json) {
        formOps.outputResponse('ok', dates, res, null, null, null, true);
      } else {

        formOps.dynamicPage(res, domManipulator.graphs(dates, req.language));

      }

    }

  });

};