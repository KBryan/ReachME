'reach 0.1';

const NUM_OF_WINNERS = 3;

const CommonInterface = {
  showOutcome: Fun([Array(Address, NUM_OF_WINNERS)], Null),
};

const GovernernanceInterface = {
  ...CommonInterface,
  getParams: Fun([], Object({
    deadline: UInt, // relative deadline
    ticketPrice: UInt,
  })),
};

const VoterInterface = {
  ...CommonInterface,
  shouldBuyTicket: Fun([UInt], Bool),
  showPurchase: Fun([Address], Null),
};

export const main = Reach.App(
    { },
    [
      ['Governer', GovernernanceInterface], ['class', 'Voter', VoterInterface],
    ],
    (Governer, Voter) => {
      const showOutcome = (winners) =>
          each([Governer, Voter], () => interact.showOutcome(winners));

        Governer.only(() => {
        const { ticketPrice, deadline } = declassify(interact.getParams()); });
        Governer.publish(ticketPrice, deadline);

      const initialWinners = Array.replicate(NUM_OF_WINNERS, Governer);

      // Until deadline, allow buyers to buy ticket
      const [ keepGoing, winners, ticketsSold ] =
          parallel_reduce([ true, initialWinners, 0 ])
              .invariant(balance() == ticketsSold * ticketPrice)
              .while(keepGoing)
              .case(
                  Voter,
                  (() => ({
                    when: declassify(interact.shouldBuyTicket(ticketPrice)) })),
                  (() => ticketPrice),
                  () => {
                    const buyer = this;
                      Voter.only(() => interact.showPurchase(buyer));
                    const idx = ticketsSold % NUM_OF_WINNERS;
                    const newWinners =
                        Array.set(winners, idx, buyer);
                    return [ true, newWinners, ticketsSold + 1 ]; })
              .timeout(deadline, () => {
                race(Voter, Governer).publish();
                return [ false, winners, ticketsSold ]; });

      transfer(balance() % NUM_OF_WINNERS).to(Governer);
      const reward = balance() / NUM_OF_WINNERS;

      winners.forEach(winner =>
          transfer(reward).to(winner));

      commit();
      showOutcome(winners);
    });
