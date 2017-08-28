% some function not dependent on main.m but dependent on others
% it is self-recursive
% it generates recursion to dependency_1 because this function is called by dependency_2 which is
% called by dependency_1
function dependency_3()
        dependency_1();
        dependency_3();
end
