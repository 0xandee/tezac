'use client';

import React, { useCallback, useState } from 'react';
import { useContract } from '../hooks/useContract';
import { toast } from 'react-toastify';
import { AztecAddress } from '@aztec/aztec.js';

interface OwnershipData {
    owner: string;
    timestamp: string;
}

const VerifyOwnership: React.FC = () => {
    const [tokenId, setTokenId] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [result, setResult] = useState<OwnershipData | null>(null);
    const [notFound, setNotFound] = useState(false);
    const [listingPrice, setListingPrice] = useState('');
    const [listingResult, setListingResult] = useState<string | null>(null);
    const { contract, deploy, wait } = useContract();

    const handleChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        setTokenId(e.target.value);
        setResult(null);
        setNotFound(false);
    }, []);

    const handleSubmit = useCallback(async (e: React.FormEvent) => {
        e.preventDefault();

        if (!tokenId) {
            alert('Please enter a token ID');
            return;
        }

        if (!contract) {
            alert('Contract not deployed');
            return;
        }

        setIsLoading(true);
        setResult(null);
        setNotFound(false);

        try {
            const ownerOfInteraction = contract.methods.owner_of(tokenId);
            const owner = await ownerOfInteraction.simulate();
            
            if (owner) {
                setResult({
                    owner: owner.toString(),
                    timestamp: new Date().toISOString()
                });
            } else {
                setNotFound(true);
            }
        } catch (error) {
            console.error('Error verifying ownership:', error);
            setNotFound(true);
        } finally {
            setIsLoading(false);
        }
    }, [tokenId, contract]);

    const handleListNFT = useCallback(async (e: React.FormEvent) => {
        e.preventDefault();

        if (!tokenId || !listingPrice) {
            alert('Please enter a token ID and listing price');
            return;
        }

        if (!contract) {
            alert('Contract not deployed');
            return;
        }

        setIsLoading(true);
        setListingResult(null);

        try {
            const zeroAddress = AztecAddress.ZERO;
            const price = BigInt(listingPrice) * BigInt(1e18); // Convert to wei
            
            const listInteraction = contract.methods.list(
                tokenId,
                price,
                zeroAddress
            );
            
            const tx = await listInteraction.send().wait();
            
            setListingResult(`NFT ${tokenId} listed for ${listingPrice} ETH (Tx: ${tx.txHash})`);
            toast.success('NFT listed successfully');
        } catch (error) {
            console.error('Error listing NFT:', error);
            toast.error('Failed to list NFT');
        } finally {
            setIsLoading(false);
        }
    }, [tokenId, listingPrice, contract]);

    const formatDate = (timestamp: string) => {
        const date = new Date(timestamp);
        return date.toLocaleString();
    };

    return (
        <div className="form-container">
            <div className="page-header">
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '10px', marginBottom: '10px', width: '100%' }}>
                    <h2 className="form-title">
                        Verify NFT Ownership
                    </h2>
                    <p style={{ margin: 0 }}>
                        Verify the ownership of an NFT without revealing the owner's address and token ID.
                    </p>
                </div>
            </div>

            {!contract && (
                <form onSubmit={deploy}>
                    <button type="submit" disabled={wait} className="button-primary button-full">
                        {wait ? 'Deploying...' : 'Deploy NFT Contract'}
                    </button>
                </form>
            )}

            {contract && (
                <>
                    <form onSubmit={handleSubmit}>
                        <div className="form-group">
                            <label htmlFor="tokenId" className="form-label">Token ID</label>
                            <input
                                type="text"
                                id="tokenId"
                                value={tokenId}
                                onChange={handleChange}
                                placeholder="Enter token ID (e.g., 123)"
                                className="form-input"
                                required
                            />
                        </div>

                        <button type="submit" disabled={isLoading} className="button-primary button-full">
                            {isLoading ? 'Verifying...' : 'Verify Ownership'}
                        </button>
                    </form>

                    {(result || notFound) && (
                        <div className={`alert ${notFound ? 'alert-error' : 'alert-success'}`}>
                            <h3 style={{
                                margin: '0 0 15px 0',
                                color: notFound ? 'var(--error-color)' : 'var(--accent-primary)'
                            }}>
                                Verification Result
                            </h3>

                            {notFound ? (
                                <p style={{ margin: '0', color: 'var(--error-color)' }}>
                                    No ownership data found for token ID: {tokenId}
                                </p>
                            ) : result && (
                                <div>
                                    <div style={{ marginBottom: '10px' }}>
                                        <span style={{ color: 'var(--text-secondary)' }}>Token ID: </span>
                                        <span style={{ color: 'var(--text-active)' }}>{tokenId}</span>
                                    </div>
                                    <div style={{ marginBottom: '10px' }}>
                                        <span style={{ color: 'var(--text-secondary)' }}>Owner: </span>
                                        <span style={{ color: 'var(--text-active)' }}>{result.owner}</span>
                                    </div>
                                    <div>
                                        <span style={{ color: 'var(--text-secondary)' }}>Ownership since: </span>
                                        <span style={{ color: 'var(--text-active)' }}>{formatDate(result.timestamp)}</span>
                                    </div>
                                </div>
                            )}
                        </div>
                    )}

                    <div className="page-header">
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '10px', marginBottom: '10px', width: '100%' }}>
                            <h2 className="form-title">
                                List NFT
                            </h2>
                            <p style={{ margin: 0 }}>
                                List an NFT for sale (public listing).
                            </p>
                        </div>
                    </div>

                    <form onSubmit={handleListNFT}>
                        <div className="form-group">
                            <label htmlFor="listingPrice" className="form-label">Listing Price (ETH)</label>
                            <input
                                type="number"
                                id="listingPrice"
                                value={listingPrice}
                                onChange={(e) => setListingPrice(e.target.value)}
                                placeholder="Enter listing price in ETH"
                                className="form-input"
                                step="0.01"
                                min="0"
                                required
                            />
                        </div>

                        <button type="submit" disabled={isLoading} className="button-primary button-full">
                            {isLoading ? 'Listing...' : 'List NFT'}
                        </button>
                    </form>

                    {listingResult && (
                        <div className="alert alert-success">
                            <h3 style={{
                                margin: '0 0 15px 0',
                                color: 'var(--accent-primary)'
                            }}>
                                Listing Result
                            </h3>
                            <p style={{ margin: '0', color: 'var(--text-active)' }}>{listingResult}</p>
                        </div>
                    )}
                </>
            )}
        </div>
    );
};

export default VerifyOwnership;
