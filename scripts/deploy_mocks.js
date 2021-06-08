/*
  Deploying the mocks for testing,
  VRFCoordinatorMock.sol.  
*/

const VRFCoordinatorMock = artifacts.require('VRFCoordinatorMock');

async function main() {
  const vrfNumber = await VRFCoordinatorMock.new(
    '0x514910771af9ca656af840dff83e8264ecf986ca'
  );
  VRFCoordinatorMock.setAsDeployed(vrfNumber);

  console.log('VRFCoordinatorMock deployed to:', vrfNumber.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
