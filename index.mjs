import { loadStdlib } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
import { ask, yesno, done } from '@reach-sh/stdlib/ask.mjs';

const numOfVoters = 3;

(async () => {
  const stdlib = await loadStdlib();

  const isAlice = await ask(
      `Are you Governer?`,
      yesno
  );
  const who = isAlice ? 'Governer' : 'Voter';

  console.log(`Starting Governance ${who}`);

  const startingBalance = stdlib.parseCurrency(100);

  const accGoverner = await stdlib.newTestAccount(startingBalance);
  const accVoterArray = await Promise.all(
      Array.from({ length: numOfVoters }, () =>
          stdlib.newTestAccount(startingBalance)
      )
  );

  let acc = null;
  const createAcc = await ask(
      `Would you like to create an account? (only possible on devnet)`,
      yesno
  );

  const ctcGoverner = accGoverner.deploy(backend);
  const ctcInfo   = ctcGoverner.getInfo();

  const funderParams = {
    ticketPrice: stdlib.parseCurrency(3),
    deadline: 8,
  };

  const resultText = (outcome, addr) =>
      outcome.includes(addr) ? 'won' : 'lost';

  await Promise.all([
    backend.Governer(ctcGoverner, {
      showOutcome: (outcome) =>
          console.log(`Funder saw they ${resultText(outcome, accGoverner.networkAccount.address)}`),
      getParams: () => funderParams,
    }),
  ].concat(
      accVoterArray.map((accVoter, i) => {
        const ctcVoter = accVoter.attach(backend, ctcInfo);
        const Who = `Voter #${i}`;
        return backend.Voter(ctcVoter, {
          showOutcome: (outcome) =>
              console.log(`${Who} saw they ${resultText(outcome, accVoter.networkAccount.address)}`),
          shouldBuyTicket : () => Math.random() < 0.5,
          showPurchase: (addr) => {
            if (stdlib.addressEq(addr, accVoter)) {
              console.log(`${Who} bought a ticket.`);
            }
          }
        });
      })
  ));
})();
