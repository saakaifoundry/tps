(function () {
  var display = 'label';

  var bloodhound = new Bloodhound({
    datumTokenizer: Bloodhound.tokenizers.obj.whitespace(display),
    queryTokenizer: Bloodhound.tokenizers.whitespace,

    remote: {
      url: '/ban/search?request=%QUERY',
      wildcard: '%QUERY'
    }
  });

  bloodhound.initialize();

  var bindTypeahead = function() {
    $("input[data-address='true']").typeahead({
      minLength: 1
    }, {
      display: display,
      source: bloodhound,
      limit: 5
    });
  };

  document.addEventListener('turbolinks:load', bindTypeahead);
})();
