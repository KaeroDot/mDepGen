% this is main function of dependence testing functions
function main()
        % example of calls:
                dep1();
                dep2();
        % example of calls in comments:
                % not_called();
                # not_called();
        % repeated calls:
                dep1();
                dep2();
        % multiple calls in one line:
                dep5(); dep6();
        % call not followed by parentheses:
                called_without_parentheses
        % call of subfunction:
                submain();
        % call of some external function:
                fft()
end

% subfunction:
function submain()
    called_by_subfunction();
end
