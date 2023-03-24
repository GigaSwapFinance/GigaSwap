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
    let interval1 = 604800;
    let interval11 = 604799;
    let interval2 = 604800;
    let interval22 = 604799;

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
            expect(await stacking.timeIntervalLength()).to.eq(interval1); // 48 hours
            expect(await stacking.nextIntervalLapsedSeconds()).to.eq(interval11); // до след интервала
            expect(await stacking.intervalNumber()).to.eq(0);
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
            //await expect(stacking.erc20ClaimCountForAccount(owner.address, stackingErc20.address)).to.be.revertedWith('staking tokens can not be claimed');
            expect(await stacking.ethClaimCountForStack(1000)).to.eq(0);
            expect(await stacking.erc20ClaimCountForStack(1000, erc20.address)).to.eq(0);
        });

        it("интервалы переключаются самостоятельно", async () => {
            // ждем
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            // переключилось на след интервал
            expect(await stacking.intervalNumber()).to.eq(1);
            expect(await stacking.timeIntervalLength()).to.eq(interval2); // 7 days
            expect(await stacking.nextIntervalLapsedSeconds()).to.eq(interval2); // до след интервала
            // ждем
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            // переключилось на след интервал
            expect(await stacking.intervalNumber()).to.eq(2);
            expect(await stacking.timeIntervalLength()).to.eq(interval2); // 7 days
            expect(await stacking.nextIntervalLapsedSeconds()).to.eq(interval2); // до след интервала
        });

        it("второй интервал 7 дней", async () => {
            expect(await stacking.timeIntervalLength()).to.eq(interval2); // 7 days
            expect(await stacking.nextIntervalLapsedSeconds()).to.eq(interval22); // до след интервала

            // переводим эфир на контракт
            await owner.sendTransaction({
                to: stacking.address,
                value: ethers.utils.parseEther("3.0") // Sends exactly 1.0 ether
            });
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            await stacking.addStack(100);

            // ждем
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            await stacking.claimEth();

            // проверка след интервала
            expect(await stacking.timeIntervalLength()).to.eq(interval2); // 7 days
            expect(await stacking.nextIntervalLapsedSeconds()).to.eq(interval22); // 7 days до след интервала
        });

        it("проверка создания и вывода стака", async () => {
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            expect(await stacking.addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(100);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(100);

            // создаем второй стак
            await stackingErc20.connect(acc2).mint(200);
            await stackingErc20.connect(acc2).approve(stacking.address, 200);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 200, 100);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(2);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(300);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(300);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(2);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(2);

            // выводим 1 стак
            expect(await stacking.removeStack(100)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 100);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(200);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(200);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(2);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(2);

            // выводим часть 2 стака
            expect(await stacking.connect(acc2).removeStack(150)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 50, 150);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(50);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(50);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(150);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(50);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(2);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(2);

            // выводим вторую часть 2 стака
            expect(await stacking.connect(acc2).removeStack(50)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 50);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(0);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(200);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(0);
            expect(await stacking.ethClaimIntervalForAccount(owner.address)).to.eq(2);
            expect(await stacking.ethClaimIntervalForAccount(acc2.address)).to.eq(2);

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
            expect(await stacking.ethOnInterval()).to.eq(0);
            expect(await stacking.intervalNumber()).to.eq(0);

            // вначале не клаймится
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            expect(await stacking.intervalNumber()).to.eq(0);
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            expect(await stacking.intervalNumber()).to.eq(1);
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            expect(await stacking.intervalNumber()).to.eq(2);

            // клаймим
            expect(await stacking.ethOnInterval()).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("1.0"));
            expect(await stacking.intervalNumber()).to.eq(2);
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("0.0"));

            // после клайма нельзя клаймить повторно
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
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
            expect(await stacking.ethOnInterval()).to.eq(0);
            expect(await stacking.intervalNumber()).to.eq(0);

            // вначале не клаймится
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));

            // клаймим
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.ethClaimCountForAccount(acc2.address)).to.eq(ethers.utils.parseEther("2.0"));
            expect(await stacking.claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("1.0"));
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("2.0"));
            expect(await stacking.ethClaimCountForAccount(acc2.address)).to.eq(ethers.utils.parseEther("2.0"));

            // второй клаймит
            expect(await stacking.connect(acc2).claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("2.0"));
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("0.0"));
            expect(await stacking.ethClaimCountForAccount(acc2.address)).to.eq(ethers.utils.parseEther("0.0"));

            // после клайма нельзя клаймить повторно
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');
            await expect(stacking.connect(acc2).claimEth()).to.be.revertedWith('can not claim on current interval');

            // добавляем
            await owner.sendTransaction({
                to: stacking.address,
                value: ethers.utils.parseEther("3.0") // Sends exactly 1.0 ether
            });
            // выжидаем
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            // клейм второй раз
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(ethers.utils.parseEther("1.0"));
            expect(await stacking.ethClaimCountForAccount(acc2.address)).to.eq(ethers.utils.parseEther("2.0"));
            expect(await stacking.claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("1.0"));
            expect(await stacking.connect(acc2).claimEth()).to.emit(stacking, 'OnClaimEth').withArgs(ethers.utils.parseEther("2.0"));


            // выжидаем
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            // теперь по 0 клайм
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(ethers.utils.parseEther("0.0"));
            expect(await stacking.ethClaimCountForAccount(acc2.address)).to.eq(ethers.utils.parseEther("0.0"));
        });
    });

    describe("erc20", async () => {
        it("изначальная ситуация", async () => {
            expect(await stacking.timeIntervalLength()).to.eq(interval1); // 1 день
            expect(await stacking.nextIntervalLapsedSeconds()).to.eq(interval11); // до след интервала
            expect(await stacking.intervalNumber()).to.eq(0);
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
            //await expect(stacking.erc20ClaimCountForAccount(owner.address, stackingErc20.address)).to.be.revertedWith('staking tokens can not be claimed');
            expect(await stacking.ethClaimCountForStack(1000)).to.eq(0);
            expect(await stacking.erc20ClaimCountForStack(1000, erc20.address)).to.eq(0);
        });

        it("проверка создания и вывода стака", async () => {
            // задаем стак
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            expect(await stacking.addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(100);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(100);

            // создаем второй стак
            await stackingErc20.connect(acc2).mint(200);
            await stackingErc20.connect(acc2).approve(stacking.address, 200);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 100, 100);
            expect(await stacking.connect(acc2).addStack(100)).to.emit(stacking, 'OnAddStack').withArgs(owner.address, 200, 100);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(2);

            // стак имеется на контракте
            expect((await stacking.getStack(owner.address))[0]).to.eq(100);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(300);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(300);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(2);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(2);

            // выводим 1 стак
            expect(await stacking.removeStack(100)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 100);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(200);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(200);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(0);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(200);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(2);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(2);

            // выводим часть 2 стака
            expect(await stacking.connect(acc2).removeStack(150)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 50, 150);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(50);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(50);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(150);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(50);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(2);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(2);

            // выводим вторую часть 2 стака
            expect(await stacking.connect(acc2).removeStack(50)).to.emit(stacking, 'OnRemoveStack').withArgs(owner.address, 0, 50);
            expect((await stacking.getStack(owner.address))[0]).to.eq(0);
            expect((await stacking.getStack(owner.address))[1]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[0]).to.eq(0);
            expect((await stacking.getStack(acc2.address))[1]).to.eq(0);
            expect(await stacking.totalStacks()).to.eq(0);
            expect(await stackingErc20.balanceOf(owner.address)).to.eq(100);
            expect(await stackingErc20.balanceOf(acc2.address)).to.eq(200);
            expect(await stackingErc20.balanceOf(stacking.address)).to.eq(0);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, owner.address)).to.eq(2);
            expect(await stacking.erc20ClaimIntervalForAccount(erc20.address, acc2.address)).to.eq(2);

            // дальше выводить нельзя
            await expect(stacking.removeStack(1)).to.be.revertedWith('not enough stack count');
            await expect(stacking.connect(acc2).removeStack(1)).to.be.revertedWith('not enough stack count');
        });

        it("проверка прредположения стака erc20", async () => {
            // минтим себе стакинг токен
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            expect(await stacking.erc20ClaimCountForAccountExpect(owner.address, erc20.address)).to.eq(0);
            expect(await stacking.erc20ClaimCountForStackExpect(100, erc20.address)).to.eq(0);
            expect(await stacking.erc20ClaimCountForNewStackExpect(100, erc20.address)).to.eq(0);

            // создаем стак
            await stacking.addStack(100);
            expect(await stacking.erc20ClaimCountForAccountExpect(owner.address, erc20.address)).to.eq(0);
            expect(await stacking.erc20ClaimCountForStackExpect(100, erc20.address)).to.eq(0);
            expect(await stacking.erc20ClaimCountForNewStackExpect(100, erc20.address)).to.eq(0);

            // минтим на стакинг
            await erc20.mintTo(stacking.address, 100);
            expect(await stacking.erc20ClaimCountForAccountExpect(owner.address, erc20.address)).to.eq(100);
            expect(await stacking.erc20ClaimCountForStackExpect(100, erc20.address)).to.eq(100);
            expect(await stacking.erc20ClaimCountForStackExpect(150, erc20.address)).to.eq(100);
            expect(await stacking.erc20ClaimCountForNewStackExpect(100, erc20.address)).to.eq(50);
        });

        it("проверка прредположения стака eth", async () => {
            // минтим себе стакинг токен
            await stackingErc20.mint(100);
            await stackingErc20.approve(stacking.address, 100);
            expect(await stacking.ethClaimCountForAccountExpect(owner.address)).to.eq(0);
            expect(await stacking.ethClaimCountForStackExpect(100)).to.eq(0);
            expect(await stacking.ethClaimCountForNewStackExpect(100)).to.eq(0);

            // создаем стак
            await stacking.addStack(100);
            expect(await stacking.ethClaimCountForAccountExpect(owner.address)).to.eq(0);
            expect(await stacking.ethClaimCountForStackExpect(100)).to.eq(0);
            expect(await stacking.ethClaimCountForNewStackExpect(100)).to.eq(0);

            // минтим на стакинг
            await owner.sendTransaction({
                to: stacking.address,
                value: 100
            });
            expect(await stacking.ethClaimCountForAccountExpect(owner.address)).to.eq(100);
            expect(await stacking.ethClaimCountForStackExpect(100)).to.eq(100);
            expect(await stacking.ethClaimCountForStackExpect(150)).to.eq(100);
            expect(await stacking.ethClaimCountForNewStackExpect(100)).to.eq(50);
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
            expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(100);
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(0);
            expect(await stacking.erc20OnInterval(erc20.address)).to.eq(0);

            // вначале не клаймится
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            expect(await stacking.erc20OnInterval(erc20.address)).to.eq(0);
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            expect(await stacking.intervalNumber()).to.eq(2);

            // клаймим
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(100);
            expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimErc20').withArgs(owner.address, erc20.address, 100);
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(0);
            expect(await stacking.intervalNumber()).to.eq(2);
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(ethers.utils.parseEther("0.0"));

            // после клайма нельзя клаймить повторно
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(0);
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
            expect(await stacking.ethOnInterval()).to.eq(0);
            expect(await stacking.intervalNumber()).to.eq(0);

            // вначале не клаймится
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(0);
            await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

            // выжидаем 
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));

            // клаймим            
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(100);
            expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(200);
            expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(100);
            expect(await erc20.balanceOf(stacking.address)).to.eq(200);
            expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(200);

            // второй клаймит
            expect(await stacking.connect(acc2).claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(200);
            expect(await ethers.provider.getBalance(stacking.address)).to.eq(0);
            expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(0);

            // после клайма нельзя клаймить повторно
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(0);
            await expect(stacking.claimErc20(erc20.address)).to.be.revertedWith('can not claim on current interval');
            await expect(stacking.connect(acc2).claimErc20(erc20.address)).to.be.revertedWith('can not claim on current interval');

            // добавляем
            await erc20.mintTo(stacking.address, 300);
            // выжидаем
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            // клейм второй раз
            expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(100);
            expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(200);
            expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(100);
            expect(await stacking.connect(acc2).claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(200);

            // выжидаем
            await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
            // теперь по 0 клайм
            expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
            expect(await stacking.ethClaimCountForAccount(acc2.address)).to.eq(0);
        });
    });

    it("клайм стакового токена", async () => {
        // минтим стаковый токена на стакинг
        erc20 = stackingErc20;
        await stackingErc20.mintTo(stacking.address, 300);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(300);
        // задаем стак
        await stackingErc20.mint(100);
        await stackingErc20.approve(stacking.address, 100);
        await stacking.addStack(100);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(300);

        // задаем 2 стак
        await stackingErc20.connect(acc2).mint(200);
        await stackingErc20.connect(acc2).approve(stacking.address, 200);
        await stacking.connect(acc2).addStack(200);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(300);

        // видим баланс токена на контракте
        expect(await erc20.balanceOf(stacking.address)).to.eq(600);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(300);
        expect(await stacking.ethOnInterval()).to.eq(0);
        expect(await stacking.intervalNumber()).to.eq(0);

        // вначале не клаймится
        expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(0);
        await expect(stacking.claimEth()).to.be.revertedWith('can not claim on current interval');

        // выжидаем 
        await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
        await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(300);

        // клаймим            
        expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(100);
        expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(200);
        expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(100);
        expect(await erc20.balanceOf(stacking.address)).to.eq(500);
        expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(200);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(200);

        // второй клаймит
        expect(await stacking.connect(acc2).claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(200);
        expect(await ethers.provider.getBalance(stacking.address)).to.eq(0);
        expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(0);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(0);

        // после клайма нельзя клаймить повторно
        expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(0);
        await expect(stacking.claimErc20(erc20.address)).to.be.revertedWith('can not claim on current interval');
        await expect(stacking.connect(acc2).claimErc20(erc20.address)).to.be.revertedWith('can not claim on current interval');

        // добавляем
        await erc20.mintTo(stacking.address, 300);
        // выжидаем
        await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
        // клейм второй раз
        expect(await stacking.erc20ClaimCountForAccount(owner.address, erc20.address)).to.eq(100);
        expect(await stacking.erc20ClaimCountForAccount(acc2.address, erc20.address)).to.eq(200);
        expect(await stacking.claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(100);
        expect(await stacking.connect(acc2).claimErc20(erc20.address)).to.emit(stacking, 'OnClaimEth').withArgs(200);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(0);

        // выжидаем
        await Up(parseInt((await stacking.nextIntervalLapsedSeconds()).toString()));
        // теперь по 0 клайм
        expect(await stacking.ethClaimCountForAccount(owner.address)).to.eq(0);
        expect(await stacking.ethClaimCountForAccount(acc2.address)).to.eq(0);
        expect(await stacking.erc20TotalForRewards(erc20.address)).to.eq(0);
    });
});
