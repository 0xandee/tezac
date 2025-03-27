'use client';
import React, { useState, useEffect } from 'react';

// Mock data for active listings
const mockPublicListings: Listing[] = [
  {
    id: 1,
    tokenId: 'NFT-123',
    name: 'Cosmic Dreams #123',
    price: '0.5',
    image: 'https://placehold.co/600x400/1A1A1A/a0e82c?text=NFT+123',
    type: 'public',
  },
  {
    id: 2,
    tokenId: 'NFT-456',
    name: 'Digital Universe #456',
    price: '0.78',
    image: 'https://placehold.co/600x400/1A1A1A/a0e82c?text=NFT+456',
    type: 'public',
  },
  {
    id: 3,
    tokenId: 'NFT-789',
    name: 'Future Visions #789',
    price: '1.2',
    image: 'https://placehold.co/600x400/1A1A1A/a0e82c?text=NFT+789',
    type: 'public',
  },
];

const mockPrivateListings: Listing[] = [
  {
    id: 4,
    tokenId: 'NFT-012',
    name: 'Abstract World #012',
    price: '2.0',
    image: 'https://placehold.co/600x400/1A1A1A/a0e82c?text=NFT+012',
    type: 'private',
    allowedBuyers: ['0x1234...', '0x5678...'],
  },
  {
    id: 5,
    tokenId: 'NFT-345',
    name: 'Neon City #345',
    price: '0.65',
    image: 'https://placehold.co/600x400/1A1A1A/a0e82c?text=NFT+345',
    type: 'private',
    allowedBuyers: ['0xabcd...'],
  },
];

interface Listing {
  id: number;
  tokenId: string;
  name: string;
  price: string;
  image: string;
  type: 'public' | 'private';
  allowedBuyers?: string[];
}

const CancelListing: React.FC = () => {
  const [listings, setListings] = useState<Listing[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [cancelInProgress, setCancelInProgress] = useState<number | null>(null);
  const [activeTab, setActiveTab] = useState('public');
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedListing, setSelectedListing] = useState<Listing | null>(null);

  // Fetch listings on component mount and when tab changes
  useEffect(() => {
    const fetchListings = async () => {
      setIsLoading(true);
      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 0));

      // Set mock data based on active tab
      if (activeTab === 'public') {
        setListings(mockPublicListings);
      } else {
        setListings(mockPrivateListings);
      }
      setIsLoading(false);
    };

    fetchListings();
  }, [activeTab]);

  const openCancelModal = (listing: Listing) => {
    setSelectedListing(listing);
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedListing(null);
  };

  const handleCancelListing = async () => {
    if (!selectedListing) return;

    setCancelInProgress(selectedListing.id);
    closeModal();

    try {
      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 0));

      console.log('Cancelling listing:', selectedListing.id, 'Type:', activeTab);

      // Remove the cancelled listing from the state
      setListings(currentListings => currentListings.filter(listing => listing.id !== selectedListing.id));
    } catch (error) {
      console.error('Error cancelling listing:', error);
      alert('Failed to cancel listing. Please try again.');
    } finally {
      setCancelInProgress(null);
    }
  };

  return (
    <div className="form-container" style={{ maxWidth: '800px' }}>
      <h2 className="form-title">Your Active Listings</h2>

      <div className="tabs">
        <div className={`tab ${activeTab === 'public' ? 'active' : ''}`} onClick={() => setActiveTab('public')}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M20.91 8.84 8.56 2.23a1.93 1.93 0 0 0-1.81 0L3.1 4.13a1.93 1.93 0 0 0-.97 1.68v4.8c0 .71.44 1.35 1.1 1.62l3.6 1.42c.32.13.67.13.99 0L11 12.15c.44-.17.85-.44 1.2-.82"></path>
            <path d="M22 16.92v3.03a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-8.93a2 2 0 0 1 1.13-1.82l.22-.1A1 1 0 0 1 4 9.2v7.15a2 2 0 0 0 1.55 1.94l1.64.49c.37.11.76.11 1.13 0l7.53-2.26a2 2 0 0 0 1.45-1.94v-3.19c0-.92-.51-1.35-.77-1.55L16 10"></path>
            <path d="M20 13v-2a1 1 0 0 0-1-1h-6a1 1 0 0 0-1 1v2a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1Z"></path>
          </svg>
          Public Listings
        </div>
        <div className={`tab ${activeTab === 'private' ? 'active' : ''}`} onClick={() => setActiveTab('private')}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <rect width="18" height="11" x="3" y="11" rx="2" ry="2"></rect>
            <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
          </svg>
          Private Listings
        </div>
      </div>

      <div className="tab-content">
        {isLoading ? (
          <div style={{ textAlign: 'center', padding: '40px 0' }}>Loading your {activeTab} listings...</div>
        ) : listings.length === 0 ? (
          <div className="empty-state">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="48"
              height="48"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="12" cy="12" r="10"></circle>
              <path d="M8 15h8"></path>
              <path d="M9 9h.01"></path>
              <path d="M15 9h.01"></path>
            </svg>
            <p>You don't have any active {activeTab} listings at the moment.</p>
          </div>
        ) : (
          <div>
            {listings.map(listing => (
              <div
                key={listing.id}
                className="nft-card"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  padding: '15px',
                  marginBottom: '15px',
                }}
              >
                <img
                  src={listing.image}
                  alt={listing.name}
                  style={{
                    width: '80px',
                    height: '80px',
                    objectFit: 'cover',
                    borderRadius: '4px',
                    marginRight: '15px',
                  }}
                />

                <div style={{ flex: 1 }}>
                  <h3 className="nft-title">{listing.name}</h3>
                  <p className="nft-description">Token ID: {listing.tokenId}</p>
                  <p className="nft-price">Price: {listing.price} ETH</p>
                </div>

                <button
                  onClick={() => openCancelModal(listing)}
                  disabled={cancelInProgress === listing.id}
                  className="button-secondary"
                >
                  {cancelInProgress === listing.id ? 'Cancelling...' : 'Cancel Listing'}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {modalOpen && selectedListing && (
        <div
          className="modal-overlay"
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.75)',
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            zIndex: 1000,
            backdropFilter: 'blur(4px)',
          }}
        >
          <div
            className="modal-content"
            style={{
              backgroundColor: '#1a1a1a',
              color: '#e0e0e0',
              borderRadius: '12px',
              padding: '28px',
              width: '90%',
              maxWidth: '500px',
              boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4)',
              border: '1px solid rgba(255, 255, 255, 0.08)',
            }}
          >
            <div
              className="modal-header"
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '20px',
                borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
                paddingBottom: '12px',
              }}
            >
              <h3 style={{ margin: 0, color: '#ffffff', fontWeight: '600' }}>Confirm Cancellation</h3>
              <button
                onClick={closeModal}
                style={{
                  background: 'rgba(255, 255, 255, 0.1)',
                  border: 'none',
                  cursor: 'pointer',
                  fontSize: '18px',
                  color: '#ffffff',
                  width: '32px',
                  height: '32px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  transition: 'background 0.2s ease',
                }}
                onMouseOver={e => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)')}
                onMouseOut={e => (e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)')}
              >
                ×
              </button>
            </div>

            <div className="modal-body" style={{ marginBottom: '28px' }}>
              <p style={{ fontSize: '16px', lineHeight: '1.5' }}>Are you sure you want to cancel this listing?</p>

              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  padding: '16px',
                  backgroundColor: 'rgba(255, 255, 255, 0.05)',
                  borderRadius: '10px',
                  marginTop: '20px',
                  border: '1px solid rgba(255, 255, 255, 0.08)',
                }}
              >
                <div
                  style={{
                    width: '70px',
                    height: '70px',
                    borderRadius: '8px',
                    overflow: 'hidden',
                    marginRight: '16px',
                    boxShadow: '0 4px 12px rgba(0, 0, 0, 0.3)',
                    position: 'relative',
                  }}
                >
                  <img
                    src={selectedListing.image}
                    alt={selectedListing.name}
                    style={{
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover',
                    }}
                  />
                  <div
                    style={{
                      position: 'absolute',
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      boxShadow: 'inset 0 0 0 1px rgba(255, 255, 255, 0.1)',
                      borderRadius: '8px',
                    }}
                  />
                </div>
                <div style={{ flex: 1 }}>
                  <h4 style={{ margin: '0 0 6px 0', color: '#ffffff', fontSize: '18px' }}>{selectedListing.name}</h4>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                    <span
                      style={{
                        backgroundColor: 'rgba(255, 255, 255, 0.08)',
                        padding: '3px 8px',
                        borderRadius: '4px',
                        fontSize: '13px',
                        color: '#a0e82c',
                      }}
                    >
                      Token ID: {selectedListing.tokenId}
                    </span>
                    <span
                      style={{
                        backgroundColor: 'rgba(255, 255, 255, 0.08)',
                        padding: '3px 8px',
                        borderRadius: '4px',
                        fontSize: '13px',
                        color: '#a0e82c',
                      }}
                    >
                      {selectedListing.type.charAt(0).toUpperCase() + selectedListing.type.slice(1)}
                    </span>
                  </div>
                  <p
                    style={{
                      margin: '8px 0 0 0',
                      fontWeight: 'bold',
                      fontSize: '16px',
                      color: '#ffffff',
                    }}
                  >
                    <span
                      style={{
                        backgroundColor: 'rgba(160, 232, 44, 0.1)',
                        padding: '4px 10px',
                        borderRadius: '6px',
                        color: '#a0e82c',
                        display: 'inline-block',
                      }}
                    >
                      {selectedListing.price} ETH
                    </span>
                  </p>
                </div>
              </div>

              <div
                style={{
                  marginTop: '20px',
                  padding: '12px',
                  borderRadius: '6px',
                  backgroundColor: 'rgba(255, 87, 87, 0.1)',
                  border: '1px solid rgba(255, 87, 87, 0.2)',
                }}
              >
                <p style={{ margin: 0, color: '#ff5757', fontSize: '14px', lineHeight: '1.5' }}>
                  <strong>Warning:</strong> This action cannot be undone. You will need to create a new listing if you
                  wish to sell this NFT again.
                </p>
              </div>
            </div>

            <div
              className="modal-footer"
              style={{
                display: 'flex',
                justifyContent: 'flex-end',
                gap: '12px',
                borderTop: '1px solid rgba(255, 255, 255, 0.1)',
                paddingTop: '20px',
              }}
            >
              <button
                onClick={closeModal}
                className="button-secondary"
                style={{
                  padding: '10px 16px',
                  border: '1px solid rgba(255, 255, 255, 0.15)',
                  borderRadius: '6px',
                  backgroundColor: 'transparent',
                  color: '#e0e0e0',
                  fontSize: '14px',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                }}
                onMouseOver={e => {
                  e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)';
                  e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.25)';
                }}
                onMouseOut={e => {
                  e.currentTarget.style.backgroundColor = 'transparent';
                  e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.15)';
                }}
              >
                Cancel
              </button>
              <button
                onClick={handleCancelListing}
                className="button-primary"
                style={{
                  padding: '10px 20px',
                  backgroundColor: '#a0e82c',
                  color: '#000000',
                  border: 'none',
                  borderRadius: '6px',
                  fontWeight: '600',
                  fontSize: '14px',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                  boxShadow: '0 2px 10px rgba(160, 232, 44, 0.3)',
                }}
                onMouseOver={e => {
                  e.currentTarget.style.backgroundColor = '#b1f43d';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(160, 232, 44, 0.4)';
                }}
                onMouseOut={e => {
                  e.currentTarget.style.backgroundColor = '#a0e82c';
                  e.currentTarget.style.boxShadow = '0 2px 10px rgba(160, 232, 44, 0.3)';
                }}
              >
                Confirm Cancellation
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CancelListing;
