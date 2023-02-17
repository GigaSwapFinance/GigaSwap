const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { Up, Days, Seconds } = require("./Helpers/TimeHelper");
const { ethers, waffle } = require("hardhat");

describe("stacking:", function () {
    let dealsController;
    let erc20Token;
    let owner;
    let acc1;
    let acc2;
    let addrs;
    let zeroAddress = '0x0000000000000000000000000000000000000000';
    let stackingErc20;
    let stacking;
    let erc20;

    // перед каждым тестом деплоим контракт
    beforeEach(async () => {
        [owner, acc1, acc2, ...addrs] = await ethers.getSigners();

        // создаем стаковый токен
        stackingErc20 = await (await ethers.getContractFactory("Erc20TestToken")).deploy(0);
        // создаем стакинг
        stacking = await (await ethers.getContractFactory("Farming")).deploy(stackingErc20.address);
        // создаем ерц20 для тестирования
        erc20 = await (await ethers.getContractFactory("Erc20TestToken")).deploy(0);
    });

    describe("ethereum", async () => {
        it("изначальная ситуация", async () => {
            expect(await stacking.timeInterval()).to.eq(604800); // 1 неделя
            expect(await stacking.nextEthIntervalLapsedSeconds()).to.eq(604799); // до след интервала 1 неделя
            expect(await stacking.ethIntervalNumber()).to.eq(0);
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(0);
            expect(await stacking.ethClaimForStack(1000)).to.eq(0);
        });

        it("проверка создания и вывода стака", async () => {
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            expect(await stacking.addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(100);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(100);

            // создаем второй стак
            await stackingErc20.connect(acc2).mint(200);
            await stackingErc20.connect(acc2).approve(stacking.address, 200);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 200, 100);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(1);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(300);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(300);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(1);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(1);

            // выводим 1 стак
            expect(await stacking.removeStack(100)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 100);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(200);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(200);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(1);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(1);

            // выводим часть 2 стака
            expect(await stacking.connect(acc2).removeStack(150)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 50, 150);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(50);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(50);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(150);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(50);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(1);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(1);

            // выводим вторую часть 2 стака
            expect(await stacking.connect(acc2).removeStack(50)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 50);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(0);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(200);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(0);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(1);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(1);

            // дальше выводить нельзя
            await expect(stacking.removeStack(1)).to.be.revertedWith('not enough stack count');
            await expect(stacking.connect(acc2).removeStack(1)).to.be.revertedWith('not enough stack count');
        });

        it("забираем эфир целиком из ревард пула", async () => {
            // переводим эфир на контракт
            await owner.sendTransaction({
                to: stacking.address,
                value: ethers.utils.parseEther("1.0") // Sends exactly 1.0 ether
            });
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            await stacking.addStack(100);

            // видим баланс эфира на контракте
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.totalEthForClaimOnInterval()).to.eq(0);
            expect(await stacking.ethIntervalNumber()).to.eq(0);

            // вначале не клаймится
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            expect(await stacking.ethIntervalNumber()).to.eq(0);
            await Up(Seconds(604800));
            expect(await stacking.ethIntervalNumber()).to.eq(1);

            // клаймим
            expect(await stacking.totalEthForClaimOnInterval()).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("1.0"));
            expect(await stacking.ethIntervalNumber()).to.eq(1);
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("0.0"));

            // после клайма нельзя клаймить повторно
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');
        });

        it("забираем разное количество эфира из ревард пула", async () => {
            // переводим эфир на контракт
            await owner.sendTransaction({
                to: stacking.address,
                value: ethers.utils.parseEther("3.0") // Sends exactly 1.0 ether
            });
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            await stacking.addStack(100);

            // задаем 2 стак
            await stackingErc20.connect(acc2).mint(200);
            await stackingErc20.connect(acc2).approve(stacking.address, 200);
            await stacking.connect(acc2).addStack(200);

            // видим баланс эфира на контракте
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("3.0"));
            expect(await stacking.totalEthForClaimOnInterval()).to.eq(0);
            expect(await stacking.ethIntervalNumber()).to.eq(0);

            // вначале не клаймится
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            await Up(Seconds(604800));

            // клаймим
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.expectedClaimEth(acc2.address)).to.eq(ethers.utils.parseEther("2.0"));
            expect(await stacking.claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("1.0"));
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("2.0"));
            expect(await stacking.expectedClaimEth(acc2.address)).to.eq(ethers.utils.parseEther("2.0"));

            // второй клаймит
            expect(await stacking.connect(acc2).claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("2.0"));
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("0.0"));
            expect(await stacking.expectedClaimEth(acc2.address)).to.eq(ethers.utils.parseEther("0.0"));

            // после клайма нельзя клаймить повторно
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');
            await expect(stacking.connect(acc2).claimEth()).to.be.revertedWith('can not claim on current interval');

            // добавляем
            await owner.sendTransaction({
                to: stacking.address,
                value: ethers.utils.parseEther("3.0") // Sends exactly 1.0 ether
            });
            // выжидаем
            await Up(Seconds(604800));
            // клейм второй раз
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.expectedClaimEth(acc2.address)).to.eq(ethers.utils.parseEther("2.0"));
            expect(await stacking.claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("1.0"));
            expect(await stacking.connect(acc2).claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("2.0"));


            // выжидаем
            await Up(Seconds(604800));
            // теперь по 0 клайм
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(ethers.utils.parseEther("0.0"));
            expect(await stacking.expectedClaimEth(acc2.address)).to.eq(ethers.utils.parseEther("0.0"));
        });
    });

    describe("erc20", async () => {
        it("изначальная ситуация", async () => {
            expect(await stacking.timeInterval()).to.eq(604800); // 1 неделя
            expect(await stacking.nextErc20IntervalLapsedSeconds(erc20.address)).to.eq(604799); // до след интервала 1 неделя
            expect(await stacking.erc20IntervalNumber(erc20.address)).to.eq(0);
            expect(await stacking.expectedClaimErc20(erc20.address, owner.address)).to.eq(0);
            expect(await stacking.erc20ClaimForStack(erc20.address, 1000)).to.eq(0);
        });

        it("проверка создания и вывода стака", async () => {
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            expect(await stacking.addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(100);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(100);

            // создаем второй стак
            await stackingErc20.connect(acc2).mint(200);
            await stackingErc20.connect(acc2).approve(stacking.address, 200);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 200, 100);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(1);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(300);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(300);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(1);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(1);

            // выводим 1 стак
            expect(await stacking.removeStack(100)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 100);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(200);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(200);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(1);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(1);

            // выводим часть 2 стака
            expect(await stacking.connect(acc2).removeStack(150)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 50, 150);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(50);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(50);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(150);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(50);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(1);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(1);

            // выводим вторую часть 2 стака
            expect(await stacking.connect(acc2).removeStack(50)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 50);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.stacksTotalCount()).to.eq(0);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(200);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(0);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(1);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(1);

            // дальше выводить нельзя
            await expect(stacking.removeStack(1)).to.be.revertedWith('not enough stack count');
            await expect(stacking.connect(acc2).removeStack(1)).to.be.revertedWith('not enough stack count');
        });

        it("забираем токен целиком из ревард пула", async () => {
            // переводим токен на контракт
            await erc20.mintTo(stacking.address, 100);
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            await stacking.addStack(100);

            // видим баланс на контракте
            expect(await erc20.balanceOf(stacking.address)).to.eq(100);
            expect(await stacking.totalErc20ForClaimOnInterval(erc20.address)).to.eq(0);
            expect(await stacking.erc20IntervalNumber(erc20.address)).to.eq(0);

            // вначале не клаймится
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            expect(await stacking.erc20IntervalNumber(erc20.address)).to.eq(0);
            await Up(Seconds(604800));
            expect(await stacking.erc20IntervalNumber(erc20.address)).to.eq(1);

            // клаймим
            expect(await stacking.expectedClaimErc20(erc20.address, owner.address)).to.eq(100);
            expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(100);
            expect(await stacking.erc20IntervalNumber(erc20.address)).to.eq(1);
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("0.0"));

            // после клайма нельзя клаймить повторно
            expect(await stacking.expectedClaimErc20(erc20.address, owner.address)).to.eq(0);
            await expect(stacking.claimErc20(erc20.address)).to.be.revertedWith('can not claim on current interval');
        });

        it("забираем разное количество токена из ревард пула", async () => {
            // переводим токен на контракт
            await erc20.mintTo(stacking.address, 300);
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            await stacking.addStack(100);

            // задаем 2 стак
            await stackingErc20.connect(acc2).mint(200);
            await stackingErc20.connect(acc2).approve(stacking.address, 200);
            await stacking.connect(acc2).addStack(200);

            // видим баланс токена на контракте
            expect(await erc20.balanceOf(stacking.address)).to.eq(300);
            expect(await stacking.totalEthForClaimOnInterval()).to.eq(0);
            expect(await stacking.erc20IntervalNumber(erc20.address)).to.eq(0);

            // вначале не клаймится
            expect(await stacking.expectedClaimErc20(erc20.address, owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            await Up(Seconds(604800));

            // клаймим            
            expect(await stacking.expectedClaimErc20(erc20.address, owner.address)).to.eq(100);
            expect(await stacking.expectedClaimErc20(erc20.address, acc2.address)).to.eq(200);         
            expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(100);
            expect(await erc20.balanceOf(stacking.address)).to.eq(200);
            expect(await stacking.expectedClaimErc20(erc20.address, acc2.address)).to.eq(200);

            // второй клаймит
            expect(await stacking.connect(acc2).claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(200);
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(0);
            expect(await stacking.expectedClaimErc20(erc20.address, acc2.address)).to.eq(0);

            // после клайма нельзя клаймить повторно
            expect(await stacking.expectedClaimErc20(erc20.address, owner.address)).to.eq(0);
            await expect(stacking.claimErc20(erc20.address)).to.be.revertedWith('can not claim on current interval');
            await expect(stacking.connect(acc2).claimErc20(erc20.address)).to.be.revertedWith('can not claim on current interval');

            // добавляем
            await erc20.mintTo(stacking.address, 300);
            // выжидаем
            await Up(Seconds(604800));
            // клейм второй раз
            expect(await stacking.expectedClaimErc20(erc20.address, owner.address)).to.eq(100);
            expect(await stacking.expectedClaimErc20(erc20.address, acc2.address)).to.eq(200);
            expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(100);
            expect(await stacking.connect(acc2).claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(200);

            // выжидаем
            await Up(Seconds(604800));
            // теперь по 0 клайм
            expect(await stacking.expectedClaimEth(owner.address)).to.eq(0);
            expect(await stacking.expectedClaimEth(acc2.address)).to.eq(0);
        });
    });
});
