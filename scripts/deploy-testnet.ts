import deployTestnetWithMockswap from './deploy/testnet-mockswap';

deployTestnetWithMockswap().catch((e) => {
    console.log(e);
});
