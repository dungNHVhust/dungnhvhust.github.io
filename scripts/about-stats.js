/* Generates /about-stats.json with live post / tag / category counts
   so the About page TRANSMISSION STATS panel stays in sync with the blog
   without manual edits. Runs before generation. */
'use strict';

hexo.extend.generator.register('about-stats', function (locals) {
  return {
    path: 'about-stats.json',
    data: JSON.stringify({
      posts: locals.posts.length,
      tags: locals.tags.length,
      categories: locals.categories.length
    })
  };
});
