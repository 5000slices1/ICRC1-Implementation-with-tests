import Debug "mo:base/Debug";

import Archive "Archive/Archive.ActorTest";
import ICRC1 "ICRC1/ICRC1.ActorTest";
import ICRC2 "ICRC2/ICRC2.ActorTest";
import AccountTest "Account/Account.Test";
import Text "mo:base/Text";
import ActorSpec "./utils/ActorSpec";
import ExtendedTokenActorTest "ExtendedToken/ExtendedToken.ActorTest";

actor {
    let { run } = ActorSpec;

    let test_modules = [

        { function = ICRC1.test; description = "ICRC1.test" : Text },
        { function = ICRC2.test; description = "ICRC2.test" : Text },
        {
            function = ExtendedTokenActorTest.test;
            description = "ExtendedTokenActorTest.test" : Text;
        },
        { function = Archive.test; description = "Archive.test" : Text },
        { function = AccountTest.test; description = "Account.test" : Text }

    ];

    public func run_tests() : async () {

        var someTestsFailed = false;
        for (test in test_modules.vals()) {

            Debug.print("Running: " # test.description);
            let success = ActorSpec.run([await test.function()]);

            if (success == false) {
                //Debug.trap("\1b[46;41mTests failed\1b[0m");
                Debug.print("\1b[46;41mTests failed\1b[0m");
                someTestsFailed := true;
            } else {
                Debug.print("\1b[23;42;3m Success!\1b[0m");
            };
        };

        if (someTestsFailed) {
            Debug.trap("\1b[46;41mThere are failed tests\1b[0m");
        } else {
            Debug.print("\1b[23;42;3m Gratulation! All tests succeeded!\1b[0m");
        };
    };
};
