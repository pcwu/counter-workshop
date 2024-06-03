#[starknet::interface]
trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
    
}

#[starknet::contract]
mod Counter {
    use starknet::ContractAddress;
    use kill_switch::{ IKillSwitchDispatcher, IKillSwitchDispatcherTrait };
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnerableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch_address: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        counter: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_counter: u32, address: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_counter);
        self.kill_switch_address.write(address);
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl ICounterImpl of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();

            let contract_address = self.kill_switch_address.read();
            let is_active = IKillSwitchDispatcher { contract_address }.is_active();
            assert!(!is_active, "Kill Switch is active");

            self.counter.write(self.counter.read() + 1);
            self.emit(CounterIncreased{ counter: self.counter.read() });
        }
    }
}