cd ..
mDepGen('test_functions/', 'main'   , 'readme_figures/readme_fig1')
mDepGen('test_functions/', 'main'   , 'readme_figures/readme_fig2', {'tic'})
mDepGen('test_functions/', 'main'   , 'readme_figures/readme_fig3', {}     , {'dependency_2'})
mDepGen('test_functions/', 'main'   , 'readme_figures/readme_fig4', {}     , {}, 'plototherfuns', 1)
mDepGen('test_functions/', 'main'   , 'readme_figures/readme_fig5', {}     , {}, 'plototherfuns', 1, 'plotunknownfuns', 1)
mDepGen('test_functions/', 'main'   , 'readme_figures/readme_fig6', {}     , {}, 'plotsubfuns', 0)
mDepGen('.',               'mDepGen', 'readme_figures/readme_fig7', {}     , {}, 'plotfileframes', 0)
