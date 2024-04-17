import { icrc1 } from "../../../../src/declarations/icrc1";
import { Secp256k1KeyIdentity } from "@dfinity/identity-secp256k1";
import { Actor, HttpAgent } from '@dfinity/agent';
import { Principal } from "@dfinity/principal";

async function StartTheTests(){
    //alert('hello');    
    await DoParallelTest();
}

const admin1Principal = "qtvox-jqz3t-4anax-gw7yg-kwcuj-5hqyg-cy2rr-3vgue-jqyrd-6qdu6-2ae";

export const TokenTestInterface = ({ IDL }) => {
    return IDL.Service({
        'parallel_test_internal' : IDL.Func([], [], []),
        'parallel_test_run' : IDL.Func([], [], []),
        'parallel_test_show_counter' : IDL.Func([], [IDL.Nat], ['query']),
    });
};

export function GetRandomIdentity() {
    return Secp256k1KeyIdentity.generate();
  }

/**
 * @param {string | string[]} name
 */
function GetIdendityByName(name){

    return Secp256k1KeyIdentity.fromSeedPhrase(name);
};

function GetActor(){
    
    let ident = GetRandomIdentity();

    const agent = new HttpAgent({
        //fetch,
        identity: ident,
        //host: hostToUse
    });

    agent.fetchRootKey().catch(err=>{
        console.warn("Unable to fetch root key. Check to ensure that your local replica is running");
        console.error(err);
      });

      let canId = "bd3sg-teaaa-aaaaa-qaaba-cai";
      let actor = Actor.createActor(
          TokenTestInterface, {agent: agent, canisterId: canId}
      );
      return actor;
};



async function DoParallelTest(){


    let adminIdent = GetIdendityByName("admin1");
    
    let principalText = Principal.fromUint8Array(adminIdent.getPrincipal().toUint8Array()).toText();
    console.log("admin1 principal:");
    console.log(principalText);

    return;
    // let ident = GetRandomIdentity();

    // const agent = new HttpAgent({
    //     //fetch,
    //     identity: ident,
    //     //host: hostToUse
    // });

    // agent.fetchRootKey().catch(err=>{
    //     console.warn("Unable to fetch root key. Check to ensure that your local replica is running");
    //     console.error(err);
    //   });

    // let canId = "bd3sg-teaaa-aaaaa-qaaba-cai";
    // let actor = Actor.createActor(
    //     TokenTestInterface, {agent: agent, canisterId: canId}
    // );

    
    const prom1 = async () => {

        //let actor = GetActor();
        //await actor.parallel_test_run();
        await icrc1.parallel_test_run();
        console.log("1");
    };
    const prom2 = async () => {

        let actor = GetActor();
        await actor.parallel_test_run();
        console.log("2");
    };
    const prom3 = async () => {
        let actor = GetActor();
        await actor.parallel_test_run();
        console.log("3");
    };
    const prom4 = async () => {
        let actor = GetActor();
        await actor.parallel_test_run();
        console.log("4");
    };

    await Promise.all([prom1(),prom1(),prom1(),prom1(),prom1(),prom1()]);
    //await Promise.all([prom1(),prom2(),prom3(),prom4(),prom1(),prom2(),prom3(),prom4(),prom1(),prom2(),prom3(),prom4()]);
    

    let actor = GetActor();
    let result = await actor.parallel_test_show_counter();
    console.log("The counter is:");
    console.log(result);

}


document.addEventListener('DOMContentLoaded', async function () {

    //https://www.sitepoint.com/get-url-parameters-with-javascript/
    document.getElementById("buttonStart").addEventListener('click', async function () { await StartTheTests(); }, false);
    const queryString = window.location.search;
    console.log("Parameters were:")
    console.log(queryString);
}, false)