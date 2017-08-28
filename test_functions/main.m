% this is main function of dependence testing functions
function main()

        dependency_1();
        dependency_2();

        sub_main();

        sub_main_called_without_parenthesis;

        tic()
        toc()
        disp()

        not_a_function = [5:20];
        not_a_function(:);

end

function sub_main()
        called_by_subfunction();
end

function sub_main_called_without_parenthesis()
end
