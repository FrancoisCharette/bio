/* Francois Charette, PhD - site behaviour.
   Vanilla JS, no dependencies. Everything here is progressive enhancement:
   with JS disabled the page still reads and every link still works. */

(function () {
  'use strict';

  /* --- Sticky nav gets a border once the page has scrolled --------------- */

  var nav = document.querySelector('.site-nav');
  if (nav) {
    var setStuck = function () {
      nav.setAttribute('data-stuck', window.scrollY > 8 ? 'true' : 'false');
    };
    setStuck();
    window.addEventListener('scroll', setStuck, { passive: true });
  }

  /* --- Scrollspy: highlight the nav link for the section in view --------- */

  var links = Array.prototype.slice.call(document.querySelectorAll('.nav-links a[href^="#"]'));
  var targets = links
    .map(function (link) { return document.getElementById(link.getAttribute('href').slice(1)); })
    .filter(Boolean);

  if (targets.length && 'IntersectionObserver' in window) {
    var visible = new Set();

    var highlight = function () {
      var current = null;
      for (var i = 0; i < targets.length; i++) {
        if (visible.has(targets[i].id)) { current = targets[i].id; break; }
      }
      links.forEach(function (link) {
        if (link.getAttribute('href') === '#' + current) {
          link.setAttribute('aria-current', 'true');
        } else {
          link.removeAttribute('aria-current');
        }
      });
    };

    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { visible.add(entry.target.id); }
        else { visible.delete(entry.target.id); }
      });
      highlight();
    }, { rootMargin: '-25% 0px -60% 0px' });

    targets.forEach(function (target) { observer.observe(target); });
  }

  /* --- Publication filters ----------------------------------------------- */

  var filterBar = document.querySelector('.filters');
  var groups = Array.prototype.slice.call(document.querySelectorAll('.pub-group'));

  if (filterBar && groups.length) {
    var buttons = Array.prototype.slice.call(filterBar.querySelectorAll('.filter'));

    var apply = function (key) {
      groups.forEach(function (group) {
        group.hidden = !(key === 'all' || group.getAttribute('data-kind') === key);
      });
      buttons.forEach(function (button) {
        button.setAttribute('aria-pressed', button.getAttribute('data-filter') === key ? 'true' : 'false');
      });
    };

    filterBar.addEventListener('click', function (event) {
      var button = event.target.closest('.filter');
      if (!button) { return; }
      apply(button.getAttribute('data-filter'));
    });

    apply('all');
  }
})();
