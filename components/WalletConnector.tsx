import { useState, useEffect } from 'react';

interface WalletConnectorProps {
  onConnected: (address: string) => void;
}

export function WalletConnector({ onConnected }: WalletConnectorProps) {
  const [address, setAddress] = useState<string>('');
  const [error, setError] = useState<string>('');

  async function connect() {
    if (!window.ethereum) {
      setError('Please install MetaMask or another Web3 wallet');
      return;
    }
    try {
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      const addr = accounts[0];
      setAddress(addr);
      onConnected(addr);
    } catch (e: any) {
      setError(e.message || 'Connection failed');
    }
  }

  useEffect(() => {
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', (accounts: string[]) => {
        if (accounts.length === 0) {
          setAddress('');
        } else {
          setAddress(accounts[0]);
          onConnected(accounts[0]);
        }
      });
    }
  }, []);

  return (
    <div className="wallet-connector">
      {address ? (
        <p>Connected: {address.slice(0, 6)}...{address.slice(-4)}</p>
      ) : (
        <button onClick={connect}>Connect Wallet</button>
      )}
      {error && <p className="error">{error}</p>}
    </div>
  );
}
