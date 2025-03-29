'use client';

import React, { useState, useEffect } from 'react';
import {
  AztecAddress,
  PXE,
  Wallet,
  createPXEClient,
  getRegisteredAccounts, // Alternative function to fetch accounts
  Contract
} from '@aztec/aztec.js';

const NFT_CONTRACT_ADDRESS = '0x2950b0f290422ff86b8ee8b91af4417e1464ddfd9dda26de8af52dac9ea4f869'; 
const NFT_CONTRACT_ABI = [
  {
    name: 'transfer',
    parameters: [
      { name: 'to', type: 'address' },
      { name: 'tokenId', type: 'uint256' }
    ],
    returnTypes: [],
    visibility: 'private'
  }
];

const Transfer: React.FC = () => {
  const [formData, setFormData] = useState({
    recipient: '',
    tokenId: '',
    privateNote: ''
  });
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [activeTab, setActiveTab] = useState('public');
  const [wallet, setWallet] = useState<Wallet | null>(null);
  const [pxe, setPXE] = useState<PXE | null>(null);

  useEffect(() => {
    const initializeAztec = async () => {
      try {
        const pxeClient = await createPXEClient("http://localhost:3000");
        const accounts = await getRegisteredAccounts(pxeClient); // Updated function

        if (!accounts || accounts.length === 0) {
          throw new Error("No registered accounts found");
        }

        setPXE(pxeClient);
        setWallet(accounts[0]);
      } catch (error) {
        console.error("Failed to initialize Aztec:", error);
        alert("Failed to connect to Aztec network. Check if the local node is running.");
      }
    };

    initializeAztec();
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData({ ...formData, [name]: value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.recipient || !formData.tokenId || !wallet || !pxe) {
      alert('Please fill all required fields and ensure wallet is connected');
      return;
    }

    setIsLoading(true);

    try {
      const contract = await Contract.at(NFT_CONTRACT_ADDRESS, NFT_CONTRACT_ABI, wallet);
      const recipientAddress = AztecAddress.fromString(formData.recipient);
      const tokenId = BigInt(formData.tokenId);

      const tx = contract.methods.transfer(recipientAddress.toString(), tokenId);
      const txReceipt = activeTab === 'private'
        ? await tx.send({ private: true }).wait()
        : await tx.send().wait();

      console.log('Transferring NFT:', {
        ...formData,
        txHash: txReceipt.txHash
      }, 'Mode:', activeTab);

      setIsSuccess(true);
      setTimeout(() => {
        setFormData({ recipient: '', tokenId: '', privateNote: '' });
        setIsSuccess(false);
      }, 3000);
    } catch (error) {
      console.error('Error transferring NFT:', error);
      alert('Failed to transfer NFT. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="form-container">
      <div className="page-header">
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', margin: '10px 0', width: '100%' }}>
          <h2 className="form-title">Transfer an NFT</h2>
          <p><strong>Public transfer:</strong> Everyone can see the transfer details.</p>
          <p><strong>Private transfer:</strong> Transfer details remain confidential.</p>
        </div>
      </div>

      <div className="tabs">
        <div className={`tab ${activeTab === 'public' ? 'active' : ''}`} onClick={() => setActiveTab('public')}>
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"></path>
          </svg>
          Public Transfer
        </div>
        <div className={`tab ${activeTab === 'private' ? 'active' : ''}`} onClick={() => setActiveTab('private')}>
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect width="18" height="11" x="3" y="11" rx="2" ry="2"></rect>
            <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
          </svg>
          Private Transfer
        </div>
      </div>

      <div className="tab-content">
        {!wallet && <p>Connecting to Aztec network...</p>}
        {isSuccess && <div className="alert alert-success"><p>NFT transferred successfully in {activeTab} mode!</p></div>}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="recipient" className="form-label">Recipient Address</label>
            <input
              type="text"
              id="recipient"
              name="recipient"
              value={formData.recipient}
              onChange={handleChange}
              placeholder="Enter recipient Aztec address"
              className="form-input"
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="tokenId" className="form-label">Token ID</label>
            <input
              type="text"
              id="tokenId"
              name="tokenId"
              value={formData.tokenId}
              onChange={handleChange}
              placeholder="Enter token ID"
              className="form-input"
              required
            />
          </div>

          {activeTab === 'private' && (
            <div className="form-group">
              <label htmlFor="privateNote" className="form-label">Private Note (optional)</label>
              <input
                type="text"
                id="privateNote"
                name="privateNote"
                value={formData.privateNote}
                onChange={handleChange}
                placeholder="Add a private note"
                className="form-input"
              />
              <span className="form-helper">This note is only visible to you and the recipient</span>
            </div>
          )}

          <button type="submit" disabled={isLoading || !wallet} className="button-primary button-full">
            {isLoading ? 'Transferring...' : `Transfer NFT (${activeTab})`}
          </button>
        </form>
      </div>
    </div>
  );
};

export default Transfer;
