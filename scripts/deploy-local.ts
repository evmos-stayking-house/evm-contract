import '../crafts';
import deployLocal from './deploy/localhost';

deployLocal().catch((error) => {
    console.log(error);
});
