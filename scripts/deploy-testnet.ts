import deployTestnet from "./deploy/testnet";

deployTestnet().catch((e) => {
    console.log(e);
})